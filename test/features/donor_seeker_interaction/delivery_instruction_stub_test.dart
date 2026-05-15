import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/application/delivery_instruction_stub.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';

void main() {
  test('stub is courier-facing without donor UI boilerplate', () {
    final presets = <DonorPreset>[
      DonorPreset(
        restaurantName: 'A2B',
        orderUrl: 'https://example.com/a2b',
        menuItems: const <String>['Meals'],
        appName: 'Zomato',
        source: 'test',
        confidence: 0.9,
      ),
    ];
    final text = buildDeliveryInstructionsStub(presets);
    expect(text, contains('SharingBridge'));
    expect(text, contains('Additional details:'));
    expect(text, isNot(contains('AI-sensitized')));
    expect(text, isNot(contains('saved order shortcuts')));
    expect(text, isNot(contains('A2B')));
  });

  test('empty presets still returns courier text with donor hint', () {
    final text = buildDeliveryInstructionsStub(<DonorPreset>[]);
    expect(text, contains('Additional details:'));
    expect(text, contains('Donor Setup'));
  });

  test('reference photo flag adds courier photo line', () {
    final text = buildDeliveryInstructionsStub(
      <DonorPreset>[],
      referencePhotoIncluded: true,
    );
    expect(text, contains('Reference photo'));
  });

  test('verbal notes appear in stub when non-empty', () {
    final text = buildDeliveryInstructionsStub(
      <DonorPreset>[],
      verbalHandoverNotes: '  Blue umbrella  ',
    );
    expect(text, contains('Blue umbrella'));
  });
}
