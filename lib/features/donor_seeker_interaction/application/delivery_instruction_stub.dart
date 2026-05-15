import '../../donor_setup/domain/models/donor_preset.dart';

/// Local fallback when instruction-pack API is unreachable (courier-facing only).
String buildDeliveryInstructionsStub(
  List<DonorPreset> presets, {
  bool referencePhotoIncluded = false,
  String? verbalHandoverNotes,
}) {
  final buffer = StringBuffer()
    ..writeln(
      'This meal was arranged through SharingBridge for handover to the recipient.',
    )
    ..writeln('');

  if (referencePhotoIncluded) {
    buffer.writeln(
      'Reference photo: available to delivery partner per app policy.',
    );
    buffer.writeln('');
  }

  final trimmedVerbal = verbalHandoverNotes?.trim();
  if (trimmedVerbal != null && trimmedVerbal.isNotEmpty) {
    buffer
      ..writeln('Handover notes: $trimmedVerbal')
      ..writeln('');
  }

  buffer
    ..writeln('Additional details:')
    ..writeln('')
    ..writeln('')
    ..writeln(
      'Please deliver to the location provided in the vendor app. '
      'Identify the recipient using the handover notes and reference photo '
      'only with their consent. Hand over the package and confirm delivery '
      'in the vendor app.',
    );

  // Presets are used by the app UI (Open … buttons), not embedded in courier text.
  if (presets.isEmpty) {
    buffer.writeln('');
    buffer.writeln(
      '(Donor: save a vendor preset in Donor Setup to unlock order links on the next screen.)',
    );
  }

  return buffer.toString();
}
