import 'package:flutter/material.dart';

import '../../application/suggest_vendors_usecase.dart';
import '../../data/donor_setup_repository_impl.dart';
import '../../data/http_donor_setup_api_client.dart';
import '../../domain/models/vendor_suggestion.dart';

class DonorSetupPage extends StatefulWidget {
  const DonorSetupPage({
    super.key,
    this.suggestVendorsUseCase,
  });

  final SuggestVendorsUseCase? suggestVendorsUseCase;

  @override
  State<DonorSetupPage> createState() => _DonorSetupPageState();
}

class _DonorSetupPageState extends State<DonorSetupPage> {
  static const String _defaultApiBaseUrl = 'http://localhost:8080';
  final TextEditingController _queryController = TextEditingController();
  late final SuggestVendorsUseCase _suggestVendorsUseCase;
  final List<VendorSuggestion> _suggestions = <VendorSuggestion>[];
  bool _loading = false;
  String? _errorText;
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
        _errorText = 'Unable to fetch suggestions. $error';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
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
              onPressed: _selected.isEmpty ? null : () {},
              child: const Text('Confirm and Save Presets'),
            ),
          ],
        ),
      ),
    );
  }
}
