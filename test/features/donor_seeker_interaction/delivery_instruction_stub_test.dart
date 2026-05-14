import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/application/delivery_instruction_stub.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';

void main() {
  test('stub mentions dignity, consent, and presets', () {
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
    expect(text, contains('personal details'));
    expect(text, contains('consent'));
    expect(text, contains('photo'));
    expect(text, contains('A2B'));
    expect(text, contains('Zomato'));
  });

  test('empty presets still returns copyable guidance', () {
    final text = buildDeliveryInstructionsStub(<DonorPreset>[]);
    expect(text, contains('No saved presets'));
  });
}
