import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Reloads saved presets into [_suggestions]. When [force] is false, a completion is
  /// ignored if the user already ran [Suggest Vendors] ([_suggestionsFromSearch]) or if
  /// a newer load/search superseded this call ([_presetsLoadGeneration]).
  Future<void> _loadInitialPresets({bool force = false}) async {
    final generation = ++_presetsLoadGeneration;
    try {
      final presets = await _loadPresetsUseCase(userId: _authContext.userId);
      if (!mounted) {
        return;
      }
      if (generation != _presetsLoadGeneration) {
        return;
      }
      if (_suggestionsFromSearch && !force) {
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
      if (_suggestionsFromSearch && !force) {
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
      if (_suggestionsFromSearch && !force) {
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
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _presetsLoadGeneration++;
      _loading = true;
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
    if (_selected.isEmpty || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
      _statusText = null;
    });

    final presets = _selected
        .map(
          (index) => DonorPreset(
            restaurantName: _suggestions[index].restaurantName,
            orderUrl: _suggestions[index].orderUrl,
            menuItems: _suggestions[index].menuItems,
            appName: _suggestions[index].appName,
            source: 'ai_suggestion',
            confidence: _suggestions[index].confidence,
          ),
        )
        .toList();

    try {
      await _confirmPresetsUseCase(
        userId: _authContext.userId,
        presets: presets,
      );
      await _cachePresets(presets);
      // Replace list with server truth so the UI matches what was saved (not the
      // full mock search result with stale checkboxes).
      await _loadInitialPresets(force: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _statusText = 'Presets saved successfully.';
      });
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
            ElevatedButton(
              onPressed: _queryController.text.trim().isEmpty ? null : _search,
              child: const Text('Suggest Vendors'),
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
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (BuildContext context, int index) {
                  final selected = _selected.contains(index);
                  return CheckboxListTile(
                    isThreeLine: true,
                    title: Text(_suggestions[index].restaurantName),
                    subtitle: _suggestionTileSubtitle(_suggestions[index]),
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
                },
              ),
            ),
            ElevatedButton(
              onPressed: _selected.isEmpty || _saving ? null : _confirmAndSave,
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
