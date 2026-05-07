import '../models/donor_preset.dart';
import '../models/vendor_suggestion.dart';

abstract class DonorSetupRepository {
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  });

  Future<List<DonorPreset>> loadPresets({required String userId});

  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  });
}
