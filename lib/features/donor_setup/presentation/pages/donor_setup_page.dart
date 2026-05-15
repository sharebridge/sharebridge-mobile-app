import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/clear_presets_usecase.dart';
import '../../application/confirm_presets_usecase.dart';
import '../../application/load_presets_usecase.dart';
import '../../application/remove_preset_usecase.dart';
import '../../application/suggest_vendors_usecase.dart';
import '../../data/auth_context.dart';
import '../../data/donor_setup_api_exceptions.dart';
import '../../data/donor_setup_repository_impl.dart';
import '../../data/donor_setup_local_storage.dart';
import '../../data/http_donor_setup_api_client.dart';
import '../../domain/models/donor_preset.dart';
import '../../domain/models/vendor_suggestion.dart';
import '../widgets/manual_vendor_entry_row.dart';
import 'donor_presets_page.dart';

class DonorSetupPage extends StatefulWidget {
  const DonorSetupPage({
    super.key,
    this.suggestVendorsUseCase,
    this.confirmPresetsUseCase,
    this.loadPresetsUseCase,
    this.clearPresetsUseCase,
    this.removePresetUseCase,
    this.authContext,
  });

  final SuggestVendorsUseCase? suggestVendorsUseCase;
  final ConfirmPresetsUseCase? confirmPresetsUseCase;
  final LoadPresetsUseCase? loadPresetsUseCase;
  final ClearPresetsUseCase? clearPresetsUseCase;
  final RemovePresetUseCase? removePresetUseCase;
  final AuthContext? authContext;

  @override
  State<DonorSetupPage> createState() => _DonorSetupPageState();
}

class _DonorSetupPageState extends State<DonorSetupPage> {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _manualAreaController = TextEditingController(
    text: 'Chennai',
  );
  final Map<int, TextEditingController> _manualUrlByIndex =
      <int, TextEditingController>{};
  late final AuthContext _authContext;
  late final SuggestVendorsUseCase _suggestVendorsUseCase;
  late final ConfirmPresetsUseCase _confirmPresetsUseCase;
  late final LoadPresetsUseCase _loadPresetsUseCase;
  final List<VendorSuggestion> _suggestions = <VendorSuggestion>[];
  bool _loading = false;
  bool _saving = false;
  String? _errorText;
  String? _statusText;
  final Set<int> _selected = <int>{};
  final List<ManualVendorEntryRow> _manualRows = <ManualVendorEntryRow>[];
  final Set<String> _selectedManualIds = <String>{};
  /// When true, [_suggestions] came from [Suggest Vendors], not from server/cache.
  /// Returning from Saved presets must not replace this list with [loadPresets] only.
  bool _suggestionsFromSearch = false;

  /// Bumps when a new preset-load or search starts so slower [_loadInitialPresets]
  /// completions cannot overwrite a newer search result (common after time on Saved presets).
  int _presetsLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _authContext = widget.authContext ?? AuthContext.fromEnvironment();
    _suggestVendorsUseCase =
        widget.suggestVendorsUseCase ??
        SuggestVendorsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(
              baseUrl: _defaultApiBaseUrl,
              authContext: _authContext,
            ),
          ),
        );
    _confirmPresetsUseCase =
        widget.confirmPresetsUseCase ??
        ConfirmPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(
              baseUrl: _defaultApiBaseUrl,
              authContext: _authContext,
            ),
          ),
        );
    _loadPresetsUseCase =
        widget.loadPresetsUseCase ??
        LoadPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(
              baseUrl: _defaultApiBaseUrl,
              authContext: _authContext,
            ),
          ),
        );
    _loadInitialPresets();
  }

  /// Reloads saved presets into [_suggestions]. Ignored when [_suggestionsFromSearch]
  /// is true (search results stay on screen). Also dropped if superseded by
  /// [_presetsLoadGeneration] (stale in-flight loads).
  Future<void> _loadInitialPresets() async {
    final generation = ++_presetsLoadGeneration;
    try {
      final presets = await _loadPresetsUseCase(userId: _authContext.userId);
      if (!mounted) {
        return;
      }
      if (generation != _presetsLoadGeneration) {
        return;
      }
      if (_suggestionsFromSearch) {
        return;
      }
      setState(() {
        _suggestions
          ..clear()
          ..addAll(
            presets
                .map(
                  (preset) => VendorSuggestion(
                    restaurantName: preset.restaurantName,
                    menuItems: preset.menuItems,
                    orderUrl: preset.orderUrl,
                    appName: preset.appName,
                    confidence: preset.confidence,
                  ),
                )
                .toList(),
          );
        _selected.clear();
        _suggestionsFromSearch = false;
        _syncManualUrlControllers(_suggestions.length);
        _statusText = presets.isNotEmpty
            ? 'Loaded saved presets from server.'
            : 'No saved presets on server yet.';
      });
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (generation != _presetsLoadGeneration) {
        return;
      }
      if (_suggestionsFromSearch) {
        return;
      }
      final usedCache = await _loadCachedPresets(forGeneration: generation);
      if (usedCache) {
        return;
      }
      if (!mounted) {
        return;
      }
      if (generation != _presetsLoadGeneration) {
        return;
      }
      if (_suggestionsFromSearch) {
        return;
      }
      setState(() {
        _statusText =
            'Server unreachable while loading presets. ${_friendlyError(error)}';
      });
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _manualAreaController.dispose();
    _disposeManualUrlControllers();
    for (final ManualVendorEntryRow row in _manualRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addManualRow() {
    setState(() {
      final row = ManualVendorEntryRow();
      _manualRows.add(row);
      _selectedManualIds.add(row.id);
    });
  }

  void _removeManualRow(String id) {
    setState(() {
      final index = _manualRows.indexWhere((ManualVendorEntryRow r) => r.id == id);
      if (index < 0) {
        return;
      }
      _manualRows[index].dispose();
      _manualRows.removeAt(index);
      _selectedManualIds.remove(id);
    });
  }

  bool get _hasAnythingSelected =>
      _selected.isNotEmpty || _selectedManualIds.isNotEmpty;

  void _disposeManualUrlControllers() {
    for (final TextEditingController c in _manualUrlByIndex.values) {
      c.dispose();
    }
    _manualUrlByIndex.clear();
  }

  void _syncManualUrlControllers(int count) {
    final keysToRemove =
        _manualUrlByIndex.keys.where((int k) => k >= count).toList();
    for (final int k in keysToRemove) {
      _manualUrlByIndex.remove(k)?.dispose();
    }
    for (int i = 0; i < count; i++) {
      _manualUrlByIndex.putIfAbsent(i, TextEditingController.new);
    }
  }

  /// Donor-pasted order page from vendor app; overrides search link for that row.
  String _effectiveOrderUrl(VendorSuggestion suggestion, int index) {
    final manual = _manualUrlByIndex[index]?.text.trim() ?? '';
    if (manual.isNotEmpty) {
      final uri = Uri.tryParse(manual);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return manual;
      }
    }
    return suggestion.orderUrl.trim();
  }

  Future<void> _search() async {
    setState(() {
      _presetsLoadGeneration++;
      _loading = true;
      _disposeManualUrlControllers();
      _suggestions.clear();
      _selected.clear();
      _errorText = null;
      _statusText = null;
      _suggestionsFromSearch = false;
    });

    try {
      final results = await _suggestVendorsUseCase(
        queryText: _queryController.text.trim(),
        locationPermissionGranted: false,
        manualArea: _manualAreaController.text.trim(),
      );

      setState(() {
        _suggestions.addAll(results);
        _suggestionsFromSearch = true;
        _syncManualUrlControllers(results.length);
      });
    } catch (error) {
      setState(() {
        _errorText = 'Unable to fetch suggestions. ${_friendlyError(error)}';
        _suggestionsFromSearch = false;
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _confirmAndSave() async {
    if (!_hasAnythingSelected || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
      _statusText = null;
    });

    final presets = <DonorPreset>[];
    for (final int index in _selected) {
      final suggestion = _suggestions[index];
      presets.add(
        DonorPreset(
          restaurantName: suggestion.restaurantName,
          orderUrl: _effectiveOrderUrl(suggestion, index),
          menuItems: suggestion.menuItems,
          appName: suggestion.appName,
          source: 'ai_suggestion',
          confidence: suggestion.confidence,
        ),
      );
    }

    for (final ManualVendorEntryRow row in _manualRows) {
      if (!_selectedManualIds.contains(row.id)) {
        continue;
      }
      final preset = row.toPreset();
      if (preset == null) {
        setState(() {
          _saving = false;
          _errorText =
              'Each selected manual vendor needs restaurant name, vendor app, '
              'and a valid http/https order link.';
        });
        return;
      }
      presets.add(preset);
    }

    if (presets.isEmpty) {
      setState(() {
        _saving = false;
        _errorText = 'Select at least one vendor to save.';
      });
      return;
    }

    try {
      await _confirmPresetsUseCase(
        userId: _authContext.userId,
        presets: presets,
      );
      await _cachePresets(presets);
      if (!mounted) {
        return;
      }
      // Keep the current suggestion list (including unselected rows); only clear
      // selection so presets/back navigation do not collapse the list to saved-only.
      setState(() {
        _selected.clear();
        _selectedManualIds.clear();
        _statusText = 'Presets saved successfully.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Presets saved successfully.')),
      );
    } catch (error) {
      setState(() {
        _errorText = 'Unable to save presets. ${_friendlyError(error)}';
      });
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  String _friendlyError(Object error) {
    if (error is DonorSetupTimeoutException) {
      return 'The server took too long to respond. Please try again.';
    }
    if (error is DonorSetupNetworkException) {
      return 'Network unavailable. Check your connection and retry.';
    }
    if (error is DonorSetupServerException) {
      return 'Server is temporarily unavailable (HTTP ${error.statusCode}).';
    }
    if (error is DonorSetupBadRequestException) {
      return error.message;
    }
    if (error is DonorSetupResponseException) {
      return 'Received an unexpected response from the server.';
    }
    return error.toString();
  }

  Future<void> _cachePresets(List<DonorPreset> presets) async {
    await syncDonorSetupPresetsCache(presets);
  }

  Future<bool> _loadCachedPresets({required int forGeneration}) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(kDonorSetupPresetsCacheKey);
    if (cached == null || cached.isEmpty) {
      return false;
    }
    final decoded = jsonDecode(cached);
    if (decoded is! List) {
      return false;
    }
    final suggestions = decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => VendorSuggestion(
            restaurantName: item['restaurant_name']?.toString() ?? '',
            menuItems:
                ((item['menu_items'] as List?) ?? const [])
                    .map((e) => e.toString())
                    .toList(),
            orderUrl: item['order_url']?.toString() ?? '',
            appName: item['app_name']?.toString() ?? 'Unknown',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .where((item) => item.restaurantName.isNotEmpty)
        .toList();
    if (suggestions.isEmpty) {
      return false;
    }
    if (!mounted || forGeneration != _presetsLoadGeneration) {
      return false;
    }
    if (_suggestionsFromSearch) {
      return false;
    }
    setState(() {
      _suggestions
        ..clear()
        ..addAll(suggestions);
      _selected.clear();
      _suggestionsFromSearch = false;
      _syncManualUrlControllers(_suggestions.length);
      _statusText = 'Using cached presets (offline fallback).';
    });
    return true;
  }

  Future<void> _clearCachedPresetsAndSignOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kDonorSetupPresetsCacheKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _disposeManualUrlControllers();
      for (final ManualVendorEntryRow row in _manualRows) {
        row.dispose();
      }
      _manualRows.clear();
      _selectedManualIds.clear();
      _suggestions.clear();
      _selected.clear();
      _suggestionsFromSearch = false;
      _queryController.clear();
      _errorText = null;
      _statusText = 'Cleared cached presets and signed out locally.';
    });
  }

  /// One line per suggestion: restaurant as title; full menu list + app in subtitle
  /// (the integration-service mock returns fixed suggestions regardless of query).
  Widget _suggestionTileSubtitle(VendorSuggestion suggestion) {
    final menus = suggestion.menuItems.isEmpty
        ? 'Menu TBD'
        : suggestion.menuItems.join(', ');
    return Text(
      '$menus · ${suggestion.appName}',
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
    );
  }

  Uri? _orderUri(VendorSuggestion suggestion, int index) {
    final uri = Uri.tryParse(_effectiveOrderUrl(suggestion, index));
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    return uri;
  }

  Future<void> _copyVendorLink(String orderUrl) async {
    final trimmed = orderUrl.trim();
    if (trimmed.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link to copy.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order link copied to clipboard.')),
    );
  }

  Future<void> _openVendorLink(VendorSuggestion suggestion, int index) async {
    final uri = _orderUri(suggestion, index);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link is missing or not http/https.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open browser. Try again or check device settings.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Setup'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Saved presets',
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => DonorPresetsPage(
                    loadPresetsUseCase: _loadPresetsUseCase,
                    clearPresetsUseCase: widget.clearPresetsUseCase,
                    removePresetUseCase: widget.removePresetUseCase,
                    authContext: _authContext,
                  ),
                ),
              );
              if (mounted && !_suggestionsFromSearch) {
                await _loadInitialPresets();
              }
            },
          ),
          TextButton(
            onPressed: _clearCachedPresetsAndSignOut,
            child: const Text('Clear cache / Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _queryController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Type app, restaurant, menu hint',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _manualAreaController,
              decoration: const InputDecoration(
                labelText: 'Manual area',
                hintText: 'Enter city/area (e.g. Chennai)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: ElevatedButton(
                    onPressed: _queryController.text.trim().isEmpty || _loading
                        ? null
                        : _search,
                    child: const Text('Suggest Vendors'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _queryController.text.trim().isEmpty || _loading
                      ? null
                      : _search,
                  child: const Text('Suggest again'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const CircularProgressIndicator(),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_statusText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _statusText!,
                  style: const TextStyle(color: Colors.green),
                ),
              ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (_suggestions.isNotEmpty) ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Suggested vendors — paste an order link under each, or '
                        'add your own vendors below.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    ...List<Widget>.generate(_suggestions.length, (int index) {
                      final suggestion = _suggestions[index];
                      final selected = _selected.contains(index);
                      final canOpen = _orderUri(suggestion, index) != null;
                      final effectiveUrl = _effectiveOrderUrl(suggestion, index);
                      final canCopy = effectiveUrl.isNotEmpty;
                      final manualController = _manualUrlByIndex[index];
                      return CheckboxListTile(
                        isThreeLine: true,
                        title: Text(suggestion.restaurantName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _suggestionTileSubtitle(suggestion),
                            if (manualController != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextField(
                                  key: Key('donor_setup_manual_url_$index'),
                                  controller: manualController,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    labelText: 'Your order link (optional)',
                                    hintText:
                                        'https://… paste from Zomato or Swiggy',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.url,
                                ),
                              ),
                            if (effectiveUrl.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: SelectableText(
                                  effectiveUrl,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ),
                            if (canCopy || canOpen)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 0,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    if (canCopy)
                                      TextButton.icon(
                                        onPressed: () =>
                                            _copyVendorLink(effectiveUrl),
                                        icon: const Icon(Icons.copy, size: 18),
                                        label: const Text('Copy link'),
                                      ),
                                    if (canOpen)
                                      TextButton.icon(
                                        onPressed: () => _openVendorLink(
                                          suggestion,
                                          index,
                                        ),
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 18,
                                        ),
                                        label: const Text('Open vendor page'),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        value: selected,
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selected.remove(index);
                            } else {
                              _selected.add(index);
                            }
                          });
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Your own vendors',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Add restaurants that were not suggested, with your own order links.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ..._manualRows.map(
                    (ManualVendorEntryRow row) => ManualVendorEntryCard(
                      key: Key('donor_setup_manual_row_${row.id}'),
                      row: row,
                      selected: _selectedManualIds.contains(row.id),
                      onSelectedChanged: (bool value) {
                        setState(() {
                          if (value) {
                            _selectedManualIds.add(row.id);
                          } else {
                            _selectedManualIds.remove(row.id);
                          }
                        });
                      },
                      onRemove: () => _removeManualRow(row.id),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('donor_setup_add_manual_vendor'),
                    onPressed: _addManualRow,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another vendor'),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: !_hasAnythingSelected || _saving ? null : _confirmAndSave,
              child: Text(
                _saving ? 'Saving...' : 'Confirm and Save Presets',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
