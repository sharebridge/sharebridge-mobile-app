abstract class DonorSetupApiClient {
  Future<Map<String, dynamic>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  });

  Future<void> savePresets(List<Map<String, dynamic>> payload);
}
