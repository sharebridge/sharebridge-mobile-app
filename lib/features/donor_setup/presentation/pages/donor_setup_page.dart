import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../application/confirm_presets_usecase.dart';
import '../../application/load_presets_usecase.dart';
import '../../application/suggest_vendors_usecase.dart';
import '../../data/donor_setup_api_exceptions.dart';
import '../../data/donor_setup_repository_impl.dart';
import '../../data/http_donor_setup_api_client.dart';
import '../../domain/models/donor_preset.dart';
import '../../domain/models/vendor_suggestion.dart';

class DonorSetupPage extends StatefulWidget {
  const DonorSetupPage({
    super.key,
    this.suggestVendorsUseCase,
    this.confirmPresetsUseCase,
    this.loadPresetsUseCase,
  });

  final SuggestVendorsUseCase? suggestVendorsUseCase;
  final ConfirmPresetsUseCase? confirmPresetsUseCase;
  final LoadPresetsUseCase? loadPresetsUseCase;

  @override
  State<DonorSetupPage> createState() => _DonorSetupPageState();
}

class _DonorSetupPageState extends State<DonorSetupPage> {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String _userId = 'demo-user';
  static const String _cacheKey = 'donor_setup_presets_cache';
  final TextEditingController _queryController = TextEditingController();
  late final SuggestVendorsUseCase _suggestVendorsUseCase;
  late final ConfirmPresetsUseCase _confirmPresetsUseCase;
  late final LoadPresetsUseCase _loadPresetsUseCase;
  final List<VendorSuggestion> _suggestions = <VendorSuggestion>[];
  bool _loading = false;
  bool _saving = false;
  String? _errorText;
  String? _statusText;
  final Set<int> _selected = <int>{};

  @override
  void initState() {
    super.initState();
    _suggestVendorsUseCase =
        widget.suggestVendorsUseCase ??
        SuggestVendorsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(baseUrl: _defaultApiBaseUrl),
          ),
        );
    _confirmPresetsUseCase =
        widget.confirmPresetsUseCase ??
        ConfirmPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(baseUrl: _defaultApiBaseUrl),
          ),
        );
    _loadPresetsUseCase =
        widget.loadPresetsUseCase ??
        LoadPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(baseUrl: _defaultApiBaseUrl),
          ),
        );
    _loadInitialPresets();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _suggestions.clear();
      _selected.clear();
      _errorText = null;
      _statusText = null;
    });

    try {
      final results = await _suggestVendorsUseCase(
        queryText: _queryController.text.trim(),
        locationPermissionGranted: false,
        manualArea: 'Chennai',
      );

      setState(() {
        _suggestions.addAll(results);
      });
    } catch (error) {
      setState(() {
        _errorText = 'Unable to fetch suggestions. ${_friendlyError(error)}';
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
      await _confirmPresetsUseCase(userId: _userId, presets: presets);
      await _cachePresets(presets);
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

  Future<void> _loadInitialPresets() async {
    try {
      final presets = await _loadPresetsUseCase(userId: _userId);
      if (presets.isNotEmpty) {
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
          _statusText = 'Loaded saved presets from server.';
        });
        return;
      }
    } catch (_) {
      // Fallback to local cache when remote load fails.
    }
    await _loadCachedPresets();
  }

  Future<void> _cachePresets(List<DonorPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = presets
        .map(
          (preset) => <String, dynamic>{
            'restaurant_name': preset.restaurantName,
            'order_url': preset.orderUrl,
            'menu_items': preset.menuItems,
            'app_name': preset.appName,
            'confidence': preset.confidence,
          },
        )
        .toList();
    await prefs.setString(_cacheKey, jsonEncode(payload));
  }

  Future<void> _loadCachedPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null || cached.isEmpty) {
      return;
    }
    final decoded = jsonDecode(cached);
    if (decoded is! List) {
      return;
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
      return;
    }
    setState(() {
      _suggestions
        ..clear()
        ..addAll(suggestions);
      _statusText = 'Using cached presets (offline fallback).';
    });
  }

  String _suggestionTitle(VendorSuggestion suggestion) {
    final firstMenu =
        suggestion.menuItems.isNotEmpty ? suggestion.menuItems.first : 'Menu';
    return '${suggestion.restaurantName} - $firstMenu';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Donor Setup')),
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
                    title: Text(_suggestionTitle(_suggestions[index])),
                    subtitle: Text(_suggestions[index].appName),
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
