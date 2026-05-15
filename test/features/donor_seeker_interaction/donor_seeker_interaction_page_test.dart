import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/application/delivery_instruction_stub.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/domain/models/instruction_pack_result.dart';
import 'package:sharingbridge_mobile_app/features/donor_seeker_interaction/presentation/pages/donor_seeker_interaction_page.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/application/load_presets_usecase.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/data/auth_context.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/donor_preset.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/models/vendor_suggestion.dart';
import 'package:sharingbridge_mobile_app/features/donor_setup/domain/repositories/donor_setup_repository.dart';
import 'package:sharingbridge_mobile_app/presentation/app_home_page.dart';

class _FakeRepo implements DonorSetupRepository {
  _FakeRepo(this.presets);

  final List<DonorPreset> presets;

  @override
  Future<void> clearPresets({required String userId}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DonorPreset>> loadPresets({required String userId}) async {
    return List<DonorPreset>.from(presets);
  }

  @override
  Future<void> removePreset({
    required String userId,
    required DonorPreset preset,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> savePresets({
    required String userId,
    required List<DonorPreset> presets,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<VendorSuggestion>> suggestVendors({
    required String queryText,
    required double? lat,
    required double? lng,
    String? manualArea,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
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
    expect(find.textContaining('Quick guidance'), findsOneWidget);
  });

  testWidgets('field page loads instructions and enables vendors after copy', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall call,
    ) async {
      if (call.method == 'Clipboard.setData') {
        return;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final presets = <DonorPreset>[
      DonorPreset(
        restaurantName: 'Cafe X',
        orderUrl: 'https://example.com/order',
        menuItems: const <String>['Coffee'],
        appName: 'Swiggy',
        source: 'test',
        confidence: 0.8,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: DonorSeekerInteractionPage(
          authContext: const AuthContext(userId: 'u1', authToken: 'tok'),
          loadPresetsUseCase: LoadPresetsUseCase(_FakeRepo(presets)),
          deliveryInstructionsRequest: ({
            required List<DonorPreset> presets,
            required bool hasReferencePhoto,
            String? verbalHandoverNotes,
          }) async {
            return InstructionPackResult(
              deliveryInstructions: buildDeliveryInstructionsStub(
                presets,
                referencePhotoIncluded: hasReferencePhoto,
                verbalHandoverNotes: verbalHandoverNotes,
              ),
              packId: 'test-pack',
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Quick guidance'), findsOneWidget);
    await tester.tap(find.byKey(const Key('field_help_continue_guidance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field_help_generate_ai')), findsOneWidget);
    await tester.tap(find.byKey(const Key('field_help_generate_ai')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field_help_instruction_body')), findsOneWidget);
    expect(find.textContaining('consent'), findsWidgets);

    final openFinder = find.byKey(const Key('field_help_open_vendor_0'));
    expect(openFinder, findsOneWidget);
    expect(
      tester.widget<FilledButton>(openFinder).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('field_help_copy_instructions')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(openFinder).onPressed,
      isNotNull,
    );
    expect(find.textContaining('Instructions copied'), findsOneWidget);
  });
}
