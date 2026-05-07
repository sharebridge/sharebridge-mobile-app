import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/confirm_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/suggest_vendors_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/presentation/pages/donor_setup_page.dart';

class _FakeRepository implements DonorSetupRepository {
  int saveCalls = 0;

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    return <DonorPreset>[];
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {
    saveCalls += 1;
  }

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    return <VendorSuggestion>[
      VendorSuggestion(
        restaurantName: 'A2B',
        menuItems: const <String>['Veg Meals'],
        orderUrl: 'https://example.com',
        appName: 'Zomato',
        confidence: 0.9,
      ),
    ];
  }
}

void main() {
  testWidgets('search flow renders suggestions and confirm button exists', (
    WidgetTester tester,
  ) async {
    final useCase = SuggestVendorsUseCase(_FakeRepository());
    await tester.pumpWidget(
      MaterialApp(home: DonorSetupPage(suggestVendorsUseCase: useCase)),
    );

    await tester.enterText(
      find.byType(TextField),
      'zomato a2b mini meals',
    );
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('A2B - Veg Meals'), findsOneWidget);
    expect(find.text('Confirm and Save Presets'), findsOneWidget);
  });

  testWidgets('confirm saves selected presets and shows success text', (
    WidgetTester tester,
  ) async {
    final repo = _FakeRepository();
    final suggestUseCase = SuggestVendorsUseCase(repo);
    final confirmUseCase = ConfirmPresetsUseCase(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: DonorSetupPage(
          suggestVendorsUseCase: suggestUseCase,
          confirmPresetsUseCase: confirmUseCase,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'sangeetha uppuma');
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Confirm and Save Presets'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 1);
    expect(find.textContaining('Unable to save presets.'), findsNothing);
  });
}
