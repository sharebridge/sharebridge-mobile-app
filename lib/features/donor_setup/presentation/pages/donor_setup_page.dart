import 'package:flutter/material.dart';

class DonorSetupPage extends StatefulWidget {
  const DonorSetupPage({super.key});

  @override
  State<DonorSetupPage> createState() => _DonorSetupPageState();
}

class _DonorSetupPageState extends State<DonorSetupPage> {
  final TextEditingController _queryController = TextEditingController();
  final List<String> _suggestions = <String>[];
  bool _loading = false;
  final Set<int> _selected = <int>{};

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
    });

    await Future<void>.delayed(const Duration(milliseconds: 150));

    setState(() {
      _suggestions.addAll(
        <String>[
          'A2B - Veg Meals',
          'Saravana Bhavan - Mini Tiffin',
          'Sangeetha - Lemon Rice Combo',
        ],
      );
      _loading = false;
    });
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
            Expanded(
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (BuildContext context, int index) {
                  final selected = _selected.contains(index);
                  return CheckboxListTile(
                    title: Text(_suggestions[index]),
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
