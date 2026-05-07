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
}
