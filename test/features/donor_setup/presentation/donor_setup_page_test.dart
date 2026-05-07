import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/presentation/pages/donor_setup_page.dart';

void main() {
  testWidgets('search flow renders suggestions and confirm button exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DonorSetupPage()));

    await tester.enterText(
      find.byType(TextField),
      'zomato a2b mini meals',
    );
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('A2B - Veg Meals'), findsOneWidget);
    expect(find.text('Confirm and Save Presets'), findsOneWidget);
  });
}
