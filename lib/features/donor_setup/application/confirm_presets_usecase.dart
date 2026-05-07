import '../domain/models/donor_preset.dart';
import '../domain/repositories/donor_setup_repository.dart';

class ConfirmPresetsUseCase {
  ConfirmPresetsUseCase(this._repository);

  final DonorSetupRepository _repository;

  Future<void> call(List<DonorPreset> presets) async {
    if (presets.isEmpty) {
      throw ArgumentError('At least one confirmed preset is required.');
    }
    await _repository.savePresets(presets);
  }
}
