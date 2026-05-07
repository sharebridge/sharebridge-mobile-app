import '../domain/models/vendor_suggestion.dart';
import '../domain/repositories/donor_setup_repository.dart';

class SuggestVendorsUseCase {
  SuggestVendorsUseCase(this._repository);

  final DonorSetupRepository _repository;

  Future<List<VendorSuggestion>> call({
    required String queryText,
    required bool locationPermissionGranted,
    double? lat,
    double? lng,
    String? manualArea,
  }) async {
    if (!locationPermissionGranted &&
        (manualArea == null || manualArea.trim().isEmpty)) {
      throw StateError(
        'Location permission is missing. Ask user to enter area manually.',
      );
    }

    final suggestions = await _repository.suggestVendors(
      queryText: queryText,
      lat: locationPermissionGranted ? lat : null,
      lng: locationPermissionGranted ? lng : null,
      manualArea: locationPermissionGranted ? null : manualArea,
    );

    if (suggestions.length <= 5) {
      return suggestions;
    }
    return suggestions.take(5).toList();
  }
}
