import '../domain/repositories/donor_setup_repository.dart';

class ClearPresetsUseCase {
  ClearPresetsUseCase(this._repository);

  final DonorSetupRepository _repository;

  Future<void> call({required String userId}) {
    return _repository.clearPresets(userId: userId);
  }
}
