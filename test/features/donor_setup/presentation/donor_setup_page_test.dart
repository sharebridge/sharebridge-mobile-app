import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/clear_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/confirm_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/load_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/remove_preset_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/suggest_vendors_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/auth_context.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_api_exceptions.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_local_storage.dart';
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
    loadResult = List<DonorPreset>.from(presets);
  }

  int clearCalls = 0;

  @override
  Future<void> clearPresets({required String userId}) async {
    clearCalls += 1;
    loadResult = <DonorPreset>[];
  }

  @override
  Future<void> removePreset({
    required String userId,
    required DonorPreset preset,
  }) async {
    loadResult = loadResult
        .where(
          (DonorPreset p) =>
              p.restaurantName != preset.restaurantName ||
              p.orderUrl != preset.orderUrl,
        )
        .toList();
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

/// First [loadPresets] is delayed so tests can reproduce a race with [Suggest Vendors].
class _DelaysFirstLoadRepo extends _FakeRepository {
  int _loadCalls = 0;

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    _loadCalls++;
    if (_loadCalls == 1) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return super.loadPresets(userId: userId);
  }
}

/// Returns two suggestions so we can assert the full list survives a presets detour.
class _FakeRepositoryTwoSuggestions extends _FakeRepository {
  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    return <VendorSuggestion>[
      VendorSuggestion(
        restaurantName: 'Bistro One',
        menuItems: const <String>['Meals'],
        orderUrl: 'https://example.com/one',
        appName: 'Zomato',
        confidence: 0.9,
      ),
      VendorSuggestion(
        restaurantName: 'Bistro Two',
        menuItems: const <String>['Combo'],
        orderUrl: 'https://example.com/two',
        appName: 'Swiggy',
        confidence: 0.85,
      ),
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('slow initial load does not overwrite search results', (
    WidgetTester tester,
  ) async {
    final repo = _DelaysFirstLoadRepo();
    await tester.pumpWidget(
      MaterialApp(
        home: DonorSetupPage(
          suggestVendorsUseCase: SuggestVendorsUseCase(repo),
          loadPresetsUseCase: LoadPresetsUseCase(repo),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'lunch');
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('A2B'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('A2B'), findsOneWidget);
  });

  testWidgets('returning from saved presets keeps search suggestions list', (
    WidgetTester tester,
  ) async {
    final repo = _FakeRepositoryTwoSuggestions();
    await tester.pumpWidget(
      MaterialApp(
        home: DonorSetupPage(
          suggestVendorsUseCase: SuggestVendorsUseCase(repo),
          loadPresetsUseCase: LoadPresetsUseCase(repo),
          clearPresetsUseCase: ClearPresetsUseCase(repo),
          removePresetUseCase: RemovePresetUseCase(repo),
          authContext: const AuthContext(userId: 'u1', authToken: 't'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'lunch');
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('Bistro One'), findsOneWidget);
    expect(find.text('Bistro Two'), findsOneWidget);

    await tester.tap(find.byTooltip('Saved presets'));
    await tester.pumpAndSettle();

    expect(find.text('Saved presets'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Bistro One'), findsOneWidget);
    expect(find.text('Bistro Two'), findsOneWidget);
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
    expect(find.text('Open vendor page'), findsOneWidget);
    expect(find.text('Confirm and Save Presets'), findsOneWidget);
  });

  testWidgets('confirm save keeps all suggestions visible when only some selected', (
    WidgetTester tester,
  ) async {
    final repo = _FakeRepositoryTwoSuggestions();
    final suggestUseCase = SuggestVendorsUseCase(repo);
    final confirmUseCase = ConfirmPresetsUseCase(repo);
    final loadUseCase = LoadPresetsUseCase(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: DonorSetupPage(
          suggestVendorsUseCase: suggestUseCase,
          confirmPresetsUseCase: confirmUseCase,
          loadPresetsUseCase: loadUseCase,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'lunch');
    await tester.pump();
    await tester.tap(find.text('Suggest Vendors'));
    await tester.pumpAndSettle();

    expect(find.text('Bistro One'), findsOneWidget);
    expect(find.text('Bistro Two'), findsOneWidget);

    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.text('Confirm and Save Presets'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 1);
    expect(find.text('Bistro One'), findsOneWidget);
    expect(find.text('Bistro Two'), findsOneWidget);
    expect(find.text('Presets saved successfully.'), findsOneWidget);
  });

  testWidgets('confirm saves selected presets and shows success text', (
    WidgetTester tester,
  ) async {
    final repo = _FakeRepository();
    final suggestUseCase = SuggestVendorsUseCase(repo);
    final confirmUseCase = ConfirmPresetsUseCase(repo);
    final loadUseCase = LoadPresetsUseCase(repo);
    await tester.pumpWidget(
      MaterialApp(
        home: DonorSetupPage(
          suggestVendorsUseCase: suggestUseCase,
          confirmPresetsUseCase: confirmUseCase,
          loadPresetsUseCase: loadUseCase,
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
    expect(find.text('Presets saved successfully.'), findsOneWidget);
    expect(find.text('A2B'), findsOneWidget);
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
      kDonorSetupPresetsCacheKey:
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
