import '../domain/models/donor_preset.dart';
import '../domain/models/vendor_suggestion.dart';
import '../domain/repositories/donor_setup_repository.dart';
import 'donor_setup_api_client.dart';
import 'dto/suggest_vendors_response_dto.dart';

class DonorSetupRepositoryImpl implements DonorSetupRepository {
  DonorSetupRepositoryImpl(this._apiClient);

  final DonorSetupApiClient _apiClient;

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    final json = await _apiClient.suggestVendors(
      queryText: queryText,
      lat: lat,
      lng: lng,
      manualArea: manualArea,
    );
    return SuggestVendorsResponseDto.fromJson(json).suggestions;
  }

  @override
  Future<void> savePresets(List<DonorPreset> presets) {
    final payload = presets
        .map(
          (preset) => <String, dynamic>{
            'restaurant_name': preset.restaurantName,
            'order_url': preset.orderUrl,
            'menu_items': preset.menuItems,
            'app_name': preset.appName,
            'source': preset.source,
            'confidence': preset.confidence,
          },
        )
        .toList();

    return _apiClient.savePresets(payload);
  }
}
