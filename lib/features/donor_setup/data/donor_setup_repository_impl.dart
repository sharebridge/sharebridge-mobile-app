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
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    final payload = await _apiClient.getPresets(userId: userId);
    return payload
        .map(
          (item) => DonorPreset(
            restaurantName: item['restaurant_name']?.toString() ?? '',
            orderUrl: item['order_url']?.toString() ?? '',
            menuItems:
                ((item['menu_items'] as List?) ?? const [])
                    .map((e) => e.toString())
                    .toList(),
            appName: item['app_name']?.toString() ?? 'Unknown',
            source: item['source']?.toString() ?? 'remote',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .where((preset) => preset.restaurantName.isNotEmpty && preset.orderUrl.isNotEmpty)
        .toList();
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) {
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

    return _apiClient.savePresets(userId: userId, payload: payload);
  }

  @override
  Future<void> clearPresets({required String userId}) {
    return _apiClient.clearPresets(userId: userId);
  }

  @override
  Future<void> removePreset({
    required String userId,
    required DonorPreset preset,
  }) {
    return _apiClient.removePreset(
      userId: userId,
      restaurantName: preset.restaurantName,
      orderUrl: preset.orderUrl,
    );
  }
}
