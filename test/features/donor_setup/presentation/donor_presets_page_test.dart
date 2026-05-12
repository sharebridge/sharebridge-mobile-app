import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/clear_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/load_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/auth_context.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_api_exceptions.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/presentation/pages/donor_presets_page.dart';

class _FakePresetsRepo implements DonorSetupRepository {
  _FakePresetsRepo({
    List<DonorPreset> initial = const <DonorPreset>[],
    this.throwOnLoad = false,
  }) : _presets = List<DonorPreset>.from(initial);

  final List<DonorPreset> _presets;
  final bool throwOnLoad;
  int clearInvocations = 0;

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    if (throwOnLoad) {
      throw const DonorSetupNetworkException('offline');
    }
    return List<DonorPreset>.from(_presets);
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {}

  @override
  Future<void> clearPresets({required String userId}) async {
    clearInvocations += 1;
    _presets.clear();
  }

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async =>
      <VendorSuggestion>[];
}

void main() {
  testWidgets('shows presets with order link and action buttons', (
    WidgetTester tester,
  ) async {
    final repo = _FakePresetsRepo(
      initial: <DonorPreset>[
        DonorPreset(
          restaurantName: 'Test Bistro',
          orderUrl: 'https://vendor.example/order/1',
          menuItems: const <String>['Meals'],
          appName: 'Swiggy',
          source: 'ai_suggestion',
          confidence: 0.85,
        ),
      ],
    );
    const auth = AuthContext(userId: 'u1', authToken: 't');

    await tester.pumpWidget(
      MaterialApp(
        home: DonorPresetsPage(
          loadPresetsUseCase: LoadPresetsUseCase(repo),
          clearPresetsUseCase: ClearPresetsUseCase(repo),
          authContext: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Bistro'), findsOneWidget);
    expect(find.textContaining('vendor.example'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);
  });

  testWidgets('shows friendly error when load fails', (WidgetTester tester) async {
    final repo = _FakePresetsRepo(throwOnLoad: true);
    const auth = AuthContext(userId: 'u1', authToken: 't');

    await tester.pumpWidget(
      MaterialApp(
        home: DonorPresetsPage(
          loadPresetsUseCase: LoadPresetsUseCase(repo),
          clearPresetsUseCase: ClearPresetsUseCase(repo),
          authContext: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Network unavailable'), findsOneWidget);
  });

  testWidgets('Clear all confirms and empties list', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final repo = _FakePresetsRepo(
      initial: <DonorPreset>[
        DonorPreset(
          restaurantName: 'Test Bistro',
          orderUrl: 'https://vendor.example/order/1',
          menuItems: const <String>['Meals'],
          appName: 'Swiggy',
          source: 'ai_suggestion',
          confidence: 0.85,
        ),
      ],
    );
    const auth = AuthContext(userId: 'u1', authToken: 't');

    await tester.pumpWidget(
      MaterialApp(
        home: DonorPresetsPage(
          loadPresetsUseCase: LoadPresetsUseCase(repo),
          clearPresetsUseCase: ClearPresetsUseCase(repo),
          authContext: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Bistro'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Clear all'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byKey(const Key('confirm_clear_all_presets')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.clearInvocations, 1);
    expect(find.byKey(const ValueKey<int>(0)), findsOneWidget);
    expect(find.text('Test Bistro'), findsNothing);
    expect(find.text('No presets on server for this user.'), findsOneWidget);
    expect(find.textContaining('All presets cleared.'), findsOneWidget);
  });
}
