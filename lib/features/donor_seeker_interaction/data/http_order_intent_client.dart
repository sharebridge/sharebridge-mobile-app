import '../../donor_setup/data/auth_context.dart';
import '../../donor_setup/data/donor_setup_api_exceptions.dart';
import '../../donor_setup/data/http_donor_setup_api_client.dart';
import '../../donor_setup/domain/models/donor_preset.dart';
import '../domain/models/order_intent_registration.dart';

class HttpOrderIntentClient {
  HttpOrderIntentClient({
    required this.baseUrl,
    AuthContext? authContext,
    HttpDonorSetupApiClient? api,
  })  : _authContext = authContext ?? AuthContext.fromEnvironment(),
        _api = api ??
            HttpDonorSetupApiClient(
              baseUrl: baseUrl,
              authContext: authContext,
            );

  final String baseUrl;
  final AuthContext _authContext;
  final HttpDonorSetupApiClient _api;

  Future<OrderIntentRegistration> registerInstructionsCopied({
    required String packId,
    required List<DonorPreset> presets,
    required bool hasReferencePhoto,
    String? verbalHandoverNotes,
    DonorPreset? selectedPreset,
  }) async {
    final decoded = await _api.postDonorSeekerJson(
      path: '/v1/donor-seeker/order-intents',
      body: <String, dynamic>{
        'user_id': _authContext.userId,
        'pack_id': packId,
        'status': 'instructions_copied',
        'has_reference_photo': hasReferencePhoto,
        if (verbalHandoverNotes != null && verbalHandoverNotes.trim().isNotEmpty)
          'verbal_handover_notes': verbalHandoverNotes.trim(),
        'presets_snapshot': presets
            .map(
              (DonorPreset p) => <String, dynamic>{
                'restaurant_name': p.restaurantName,
                'menu_items': p.menuItems,
                'app_name': p.appName,
                'order_url': p.orderUrl,
              },
            )
            .toList(),
        if (selectedPreset != null)
          'selected_preset': <String, dynamic>{
            'restaurant_name': selectedPreset.restaurantName,
            'app_name': selectedPreset.appName,
            'order_url': selectedPreset.orderUrl,
          },
      },
    );

    final id = decoded['order_intent_id']?.toString();
    if (id == null || id.isEmpty) {
      throw const DonorSetupResponseException(
        'order_intent_id must be a non-empty string',
      );
    }
    return OrderIntentRegistration(
      orderIntentId: id,
      packId: decoded['pack_id']?.toString() ?? packId,
      status: decoded['status']?.toString() ?? 'instructions_copied',
      createdAt: decoded['created_at']?.toString() ?? '',
    );
  }
}
