/// Result from integration-service instruction-pack (and local stub fallback).
class InstructionPackResult {
  const InstructionPackResult({
    required this.deliveryInstructions,
    this.packId,
  });

  final String deliveryInstructions;
  final String? packId;
}
