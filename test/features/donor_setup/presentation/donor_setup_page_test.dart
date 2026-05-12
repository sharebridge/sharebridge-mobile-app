import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/confirm_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/load_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/suggest_vendors_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_api_exceptions.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/presentation/pages/donor_setup_page.dart';

class _FakeRepository implements DonorSetupRepository {
  int saveCalls = 0;
  bool throwOnLoad = false;
  List<DonorPreset> loadResult = <DonorPreset>[];

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    if (throwOnLoad) {
      throw const DonorSetupNetworkException('offline');
    }
    return loadResult;
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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('search flow renders suggestions and confirm button exists', (
    WidgetTester tester,
  ) async {
    final useCase = SuggestVendorsUseCase(_FakeRepository());
    await tester.pumpWidget(
      MaterialApp(home: DonorSetupPage(suggestVendorsUseCase: useCase)),
    );

    await tester.enterText(find.byType(TextField).first, 'zomato a2b mini meals');
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('A2B'), findsOneWidget);
    expect(find.textContaining('Veg Meals'), findsOneWidget);
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

    await tester.enterText(find.byType(TextField).first, 'sangeetha uppuma');
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

  testWidgets('shows server-empty message when API returns no presets', (
    WidgetTester tester,
  ) async {
    final repo = _FakeRepository();
    final loadUseCase = LoadPresetsUseCase(repo);
    await tester.pumpWidget(
      MaterialApp(home: DonorSetupPage(loadPresetsUseCase: loadUseCase)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved presets on server yet.'), findsOneWidget);
    expect(find.text('Using cached presets (offline fallback).'), findsNothing);
  });

  testWidgets('clear cache action removes offline presets from view', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'donor_setup_presets_cache':
          '[{"restaurant_name":"Cached Cafe","order_url":"https://cached.example","menu_items":["Meals"],"app_name":"Swiggy","confidence":0.8}]',
    });
    final repo = _FakeRepository()..throwOnLoad = true;
    final loadUseCase = LoadPresetsUseCase(repo);

    await tester.pumpWidget(
      MaterialApp(home: DonorSetupPage(loadPresetsUseCase: loadUseCase)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cached Cafe'), findsOneWidget);
    expect(find.textContaining('Meals'), findsOneWidget);

    await tester.tap(find.text('Clear cache / Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Cached Cafe'), findsNothing);
    expect(
      find.text('Cleared cached presets and signed out locally.'),
      findsOneWidget,
    );
  });
}
