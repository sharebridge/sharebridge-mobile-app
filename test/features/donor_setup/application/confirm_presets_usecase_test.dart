import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/confirm_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';

class _RecordingRepository implements DonorSetupRepository {
  List<DonorPreset> saved = <DonorPreset>[];

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    return <DonorPreset>[];
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {
    saved = presets;
  }

  @override
  Future<void> clearPresets({required String userId}) async {}

  @override
  Future<void> removePreset({
    required String userId,
    required DonorPreset preset,
  }) async {}

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    return <VendorSuggestion>[];
  }
}

void main() {
  test('saves confirmed presets', () async {
    final repo = _RecordingRepository();
    final useCase = ConfirmPresetsUseCase(repo);

    final preset = DonorPreset(
      restaurantName: 'A2B',
      orderUrl: 'https://example.com',
      menuItems: const <String>['Meals'],
      appName: 'Zomato',
      source: 'ai_suggestion',
      confidence: 0.9,
    );

    await useCase(userId: 'demo-user', presets: <DonorPreset>[preset]);
    expect(repo.saved.length, 1);
  });

  test('throws when preset list is empty', () async {
    final useCase = ConfirmPresetsUseCase(_RecordingRepository());
    expect(
      () => useCase(userId: 'demo-user', presets: <DonorPreset>[]),
      throwsA(isA<ArgumentError>()),
    );
  });
}
