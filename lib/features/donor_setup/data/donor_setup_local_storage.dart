import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/donor_preset.dart';

/// SharedPreferences key for offline donor preset cache (must stay in sync across screens).
const kDonorSetupPresetsCacheKey = 'donor_setup_presets_cache';

/// Writes [presets] to the offline cache, or clears the key when empty.
Future<void> syncDonorSetupPresetsCache(List<DonorPreset> presets) async {
  final prefs = await SharedPreferences.getInstance();
  if (presets.isEmpty) {
    await prefs.remove(kDonorSetupPresetsCacheKey);
    return;
  }
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
  await prefs.setString(kDonorSetupPresetsCacheKey, jsonEncode(payload));
}
