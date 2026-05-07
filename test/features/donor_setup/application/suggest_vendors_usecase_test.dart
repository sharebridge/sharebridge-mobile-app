import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/suggest_vendors_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';

class _FakeRepository implements DonorSetupRepository {
  @override
  Future<void> savePresets(List<DonorPreset> presets) async {}

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    return List<VendorSuggestion>.generate(
      6,
      (int index) => VendorSuggestion(
        restaurantName: 'R$index',
        menuItems: const <String>['Meals'],
        orderUrl: 'https://example.com/$index',
        appName: 'VendorApp',
        confidence: 0.8,
      ),
    );
  }
}

void main() {
  test('returns top 5 suggestions when repository gives more', () async {
    final useCase = SuggestVendorsUseCase(_FakeRepository());
    final result = await useCase(
      queryText: 'zomato meals',
      locationPermissionGranted: true,
      lat: 12.9,
      lng: 80.2,
    );
    expect(result.length, 5);
  });

  test('throws when location permission missing and no manual area', () async {
    final useCase = SuggestVendorsUseCase(_FakeRepository());
    expect(
      () => useCase(
        queryText: 'swiggy',
        locationPermissionGranted: false,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
