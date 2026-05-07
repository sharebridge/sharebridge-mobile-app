import '../domain/models/donor_preset.dart';
import '../domain/repositories/donor_setup_repository.dart';

class LoadPresetsUseCase {
  LoadPresetsUseCase(this._repository);

  final DonorSetupRepository _repository;

  Future<List<DonorPreset>> call({required String userId}) {
    return _repository.loadPresets(userId: userId);
  }
}
