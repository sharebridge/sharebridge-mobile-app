import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/clear_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';

class _SpyRepo implements DonorSetupRepository {
  String? clearedUserId;

  @override
  Future<void> clearPresets({required String userId}) async {
    clearedUserId = userId;
  }

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
  test('delegates to repository with userId', () async {
    final repo = _SpyRepo();
    final useCase = ClearPresetsUseCase(repo);
    await useCase(userId: 'alice');
    expect(repo.clearedUserId, 'alice');
  });
}
