import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/application/remove_preset_usecase.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';

class _SpyRepo implements DonorSetupRepository {
  String? seenUserId;
  DonorPreset? seenPreset;

  @override
  Future<void> removePreset({
    required String userId,
    required DonorPreset preset,
  }) async {
    seenUserId = userId;
    seenPreset = preset;
  }

  @override
  Future<void> clearPresets({required String userId}) async {}

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async =>
      <DonorPreset>[];

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {}

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async =>
      <VendorSuggestion>[];
}

void main() {
  test('delegates to repository with userId and preset', () async {
    final repo = _SpyRepo();
    final useCase = RemovePresetUseCase(repo);
    final preset = DonorPreset(
      restaurantName: 'A2B',
      orderUrl: 'https://example.com',
      menuItems: const <String>['Meals'],
      appName: 'Zomato',
      source: 'ai_suggestion',
      confidence: 0.9,
    );
    await useCase(userId: 'alice', preset: preset);
    expect(repo.seenUserId, 'alice');
    expect(repo.seenPreset?.restaurantName, 'A2B');
  });
}
