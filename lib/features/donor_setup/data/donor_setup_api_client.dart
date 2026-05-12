abstract class DonorSetupApiClient {
  Future<Map<String, dynamic>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  });

  Future<List<Map<String, dynamic>>> getPresets({required String userId});

  Future<void> savePresets({
    required String userId,
    required List<Map<String, dynamic>> payload,
  });

  /// Removes all saved presets for [userId] on the integration-service backend.
  Future<void> clearPresets({required String userId});

  /// Removes one preset identified by [restaurantName] and [orderUrl].
  Future<void> removePreset({
    required String userId,
    required String restaurantName,
    required String orderUrl,
  });
}
