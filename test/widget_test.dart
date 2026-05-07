import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/main.dart';

void main() {
  testWidgets('app boots with donor setup screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ShareBridgeApp());
    expect(find.text('Donor Setup'), findsOneWidget);
  });
}
