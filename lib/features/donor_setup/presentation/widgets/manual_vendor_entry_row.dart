import 'package:flutter/material.dart';

import '../../domain/models/donor_preset.dart';

/// Editable vendor row the donor adds beyond system suggestions.
class ManualVendorEntryRow {
  ManualVendorEntryRow({String? id})
      : id = id ?? 'manual-${DateTime.now().microsecondsSinceEpoch}';

  final String id;
  final TextEditingController restaurantController = TextEditingController();
  final TextEditingController appController = TextEditingController(text: 'Zomato');
  final TextEditingController menuController = TextEditingController();
  final TextEditingController urlController = TextEditingController();

  void dispose() {
    restaurantController.dispose();
    appController.dispose();
    menuController.dispose();
    urlController.dispose();
  }

  /// Returns preset when required fields are valid; otherwise null.
  DonorPreset? toPreset() {
    final restaurantName = restaurantController.text.trim();
    final orderUrl = urlController.text.trim();
    final appName = appController.text.trim();
    if (restaurantName.isEmpty || orderUrl.isEmpty || appName.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(orderUrl);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    final menuRaw = menuController.text.trim();
    final menuItems = menuRaw.isEmpty
        ? <String>['(not specified)']
        : menuRaw
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
    return DonorPreset(
      restaurantName: restaurantName,
      orderUrl: orderUrl,
      menuItems: menuItems,
      appName: appName,
      source: 'manual_entry',
      confidence: 1.0,
    );
  }
}

class ManualVendorEntryCard extends StatelessWidget {
  const ManualVendorEntryCard({
    super.key,
    required this.row,
    required this.selected,
    required this.onSelectedChanged,
    required this.onRemove,
    this.canRemove = true,
  });

  final ManualVendorEntryRow row;
  final bool selected;
  final ValueChanged<bool> onSelectedChanged;
  final VoidCallback onRemove;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Checkbox(
                  value: selected,
                  onChanged: (bool? value) =>
                      onSelectedChanged(value ?? false),
                ),
                Expanded(
                  child: Text(
                    'Your vendor (manual)',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove row',
                    onPressed: onRemove,
                  ),
              ],
            ),
            TextField(
              controller: row.restaurantController,
              decoration: const InputDecoration(
                labelText: 'Restaurant name',
                hintText: 'e.g. Local cafe',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.appController,
              decoration: const InputDecoration(
                labelText: 'Vendor app',
                hintText: 'Zomato, Swiggy, …',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.menuController,
              decoration: const InputDecoration(
                labelText: 'Menu items (optional)',
                hintText: 'Comma-separated, e.g. Idli, Coffee',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.urlController,
              decoration: const InputDecoration(
                labelText: 'Order page link',
                hintText: 'https://… paste from vendor app',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
    );
  }
}
