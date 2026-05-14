import '../../donor_setup/domain/models/donor_preset.dart';

/// MVP placeholder for an AI-generated delivery instruction block.
/// Replace with integration-service / model call when the pipeline exists.
String buildDeliveryInstructionsStub(
  List<DonorPreset> presets, {
  bool referencePhotoIncluded = false,
  String? verbalHandoverNotes,
}) {
  final buffer = StringBuffer()
    ..writeln('SharingBridge — delivery notes (draft, AI stub)')
    ..writeln('')
    ..writeln(
      'Be careful with personal details: only include what a courier truly '
      'needs for handover. Avoid sensitive identifiers unless the person '
      'receiving help agrees they are necessary.',
    )
    ..writeln('')
    ..writeln(
      'Before capturing any photo for delivery identification, ask for '
      'clear, voluntary consent. If they decline, use a respectful verbal '
      'description instead.',
    )
    ..writeln('');

  if (referencePhotoIncluded) {
    buffer
      ..writeln('')
      ..writeln(
        'Reference: a photo was attached for this request. When the vision '
        'API is connected, it will inform wording here; today this line is '
        'only a placeholder.',
      );
  }

  final trimmedVerbal = verbalHandoverNotes?.trim();
  if (trimmedVerbal != null && trimmedVerbal.isNotEmpty) {
    buffer
      ..writeln('')
      ..writeln('Handover notes you entered:')
      ..writeln(trimmedVerbal);
  }

  buffer
    ..writeln('')
    ..writeln(
      'Copy this block into the delivery instructions field in your vendor '
      'app after you open one of your saved order links.',
    )
    ..writeln('');

  if (presets.isEmpty) {
    buffer.writeln(
      '(No saved presets yet. Finish Donor Setup and save at least one vendor '
      'link, then return here.)',
    );
    return buffer.toString();
  }

  buffer.writeln('Your saved order shortcuts:');
  for (final DonorPreset p in presets) {
    final items = p.menuItems.isEmpty ? '(menu not listed)' : p.menuItems.join(', ');
    buffer.writeln('- ${p.restaurantName} (${p.appName}): $items');
  }
  return buffer.toString();
}
