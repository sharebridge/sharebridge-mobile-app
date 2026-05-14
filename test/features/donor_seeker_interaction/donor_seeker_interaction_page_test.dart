import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/data/field_interaction_local_storage.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/presentation/pages/donor_seeker_interaction_page.dart';
import 'package:sharingbridge_mobile_app/presentation/app_home_page.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('home hub lists donor setup and opens field flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppHomePage()),
    );

    expect(find.textContaining('Donor setup'), findsWidgets);
    expect(find.textContaining('Offer food help'), findsWidgets);

    await tester.tap(find.byKey(const Key('nav_field_flow')));
    await tester.pumpAndSettle();

    expect(find.text('Offer food help'), findsWidgets);
    expect(find.textContaining('Start here'), findsOneWidget);
  });

  testWidgets('field flow validates consent and saves draft', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DonorSeekerInteractionPage()),
    );

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Please confirm both'), findsOneWidget);
    expect(find.byKey(const Key('field_flow_gate_message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('field_flow_back')));
    await tester.pump();
    expect(find.byKey(const Key('field_flow_gate_message')), findsNothing);

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field_flow_consent_food')));
    await tester.tap(find.byKey(const Key('field_flow_consent_id')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pump();
    expect(find.textContaining('does not feel safe'), findsOneWidget);

    await tester.tap(find.byKey(const Key('field_flow_safety_ok')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('field_flow_appearance')),
      'Blue cap near the steps',
    );
    await tester.tap(find.byKey(const Key('field_flow_primary')));
    await tester.pumpAndSettle();

    final draft = await loadFieldInteractionDraft();
    expect(draft, isNotNull);
    expect(draft!.beneficiaryAppearanceNotes, 'Blue cap near the steps');
    expect(draft.foodIntentConfirmed, isTrue);
    expect(draft.identificationConsentConfirmed, isTrue);
    expect(draft.safetyFeelsOk, isTrue);
  });
}
