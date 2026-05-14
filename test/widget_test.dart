import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/main.dart';

void main() {
  testWidgets('app boots with home hub', (WidgetTester tester) async {
    await tester.pumpWidget(const SharingBridgeApp());
    expect(find.text('SharingBridge'), findsOneWidget);
    expect(find.textContaining('Donor setup'), findsWidgets);
    expect(find.textContaining('Offer food help'), findsWidgets);
  });
}
