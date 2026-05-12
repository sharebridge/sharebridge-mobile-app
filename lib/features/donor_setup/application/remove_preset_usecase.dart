import '../domain/models/donor_preset.dart';
import '../domain/repositories/donor_setup_repository.dart';

class RemovePresetUseCase {
  RemovePresetUseCase(this._repository);

  final DonorSetupRepository _repository;

  Future<void> call({required String userId, required DonorPreset preset}) {
    return _repository.removePreset(userId: userId, preset: preset);
  }
}
