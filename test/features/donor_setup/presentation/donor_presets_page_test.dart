import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/application/load_presets_usecase.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/auth_context.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/data/donor_setup_api_exceptions.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';
import 'package:sharebridge_mobile_app/features/donor_setup/presentation/pages/donor_presets_page.dart';

class _FakePresetsRepo implements DonorSetupRepository {
  _FakePresetsRepo({this.presets = const <DonorPreset>[], this.throwOnLoad = false});

  final List<DonorPreset> presets;
  final bool throwOnLoad;

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    if (throwOnLoad) {
      throw const DonorSetupNetworkException('offline');
    }
    return presets;
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {}

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
      presets: <DonorPreset>[
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
          authContext: auth,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Network unavailable'), findsOneWidget);
  });
}
