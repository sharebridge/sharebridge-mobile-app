import '../../donor_setup/domain/models/donor_preset.dart';
import '../domain/models/instruction_pack_result.dart';
import 'delivery_instruction_stub.dart';

/// Simulates a round-trip to an AI instruction API. Replace with HTTP client
/// when the backend exists.
Future<InstructionPackResult> requestStubDeliveryInstructions({
  required List<DonorPreset> presets,
  required bool hasReferencePhoto,
  String? verbalHandoverNotes,
}) async {
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return InstructionPackResult(
    deliveryInstructions: buildDeliveryInstructionsStub(
      presets,
      referencePhotoIncluded: hasReferencePhoto,
      verbalHandoverNotes: verbalHandoverNotes,
    ),
    packId: 'stub-pack-local',
  );
}
