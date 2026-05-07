import '../models/donor_preset.dart';
import '../models/vendor_suggestion.dart';

abstract class DonorSetupRepository {
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  });

  Future<void> savePresets(List<DonorPreset> presets);
}
