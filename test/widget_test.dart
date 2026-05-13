import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/main.dart';

void main() {
  testWidgets('app boots with donor setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SharingBridgeApp());
    expect(find.text('Donor Setup'), findsOneWidget);
  });
}
