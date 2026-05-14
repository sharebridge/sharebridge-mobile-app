import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/delivery_instruction_stub.dart';
import '../../../donor_setup/application/load_presets_usecase.dart';
import '../../../donor_setup/data/auth_context.dart';
import '../../../donor_setup/data/donor_setup_api_exceptions.dart';
import '../../../donor_setup/data/donor_setup_repository_impl.dart';
import '../../../donor_setup/data/http_donor_setup_api_client.dart';
import '../../../donor_setup/domain/models/donor_preset.dart';

/// Offer food help: brief dignity guidance, AI-stub instructions, copy,
/// then open saved vendor deep links from donor presets.
class DonorSeekerInteractionPage extends StatefulWidget {
  const DonorSeekerInteractionPage({
    super.key,
    this.loadPresetsUseCase,
    this.authContext,
  });

  final LoadPresetsUseCase? loadPresetsUseCase;
  final AuthContext? authContext;

  @override
  State<DonorSeekerInteractionPage> createState() =>
      _DonorSeekerInteractionPageState();
}

class _DonorSeekerInteractionPageState extends State<DonorSeekerInteractionPage> {
  static const String _defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  late final AuthContext _authContext;
  late final LoadPresetsUseCase _loadPresetsUseCase;

  List<DonorPreset> _presets = <DonorPreset>[];
  String _instructions = '';
  bool _loading = true;
  String? _errorText;
  bool _showVendorLinks = false;

  @override
  void initState() {
    super.initState();
    _authContext = widget.authContext ?? AuthContext.fromEnvironment();
    _loadPresetsUseCase =
        widget.loadPresetsUseCase ??
        LoadPresetsUseCase(
          DonorSetupRepositoryImpl(
            HttpDonorSetupApiClient(
              baseUrl: _defaultApiBaseUrl,
              authContext: _authContext,
            ),
          ),
        );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final list = await _loadPresetsUseCase(userId: _authContext.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = list;
        _instructions = buildDeliveryInstructionsStub(list);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = _friendlyLoadError(e);
        _instructions = buildDeliveryInstructionsStub(<DonorPreset>[]);
      });
    }
  }

  String _friendlyLoadError(Object e) {
    if (e is DonorSetupTimeoutException) {
      return 'Could not load presets (timeout). You can still copy instructions and open links if you know them.';
    }
    if (e is DonorSetupNetworkException) {
      return 'Could not load presets (offline). Saved vendor links appear after you reconnect.';
    }
    if (e is DonorSetupServerException) {
      return 'Could not load presets (server error). Try again in a moment.';
    }
    return 'Could not load saved presets.';
  }

  Future<void> _copyInstructions() async {
    final text = _instructions.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _showVendorLinks = true;
    });
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Instructions copied. Open a saved vendor app below and paste into delivery notes.',
        ),
      ),
    );
  }

  Uri? _orderUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return null;
    }
    return uri;
  }

  Future<void> _openPreset(DonorPreset preset) async {
    final uri = _orderUri(preset.orderUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This preset has no http/https link to open.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the app or browser. Try again or copy the link from Donor Setup.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer food help'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                Text(
                  'Quick guidance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Treat personal details with care: share only what is needed for '
                  'the courier to complete the handover with dignity.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Before taking a photo to identify the person receiving help, '
                  'ask for their consent. If they prefer not to be photographed, '
                  'use a respectful verbal description instead.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Delivery instructions (AI draft)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Generated automatically from your saved presets (live AI wiring comes later). '
                  'Tap Copy, then paste into the vendor app’s delivery notes field.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (_errorText != null) ...<Widget>[
                  Text(
                    _errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      _instructions,
                      key: const Key('field_help_instruction_body'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('field_help_copy_instructions'),
                  onPressed: _instructions.trim().isEmpty ? null : _copyInstructions,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy instructions'),
                ),
                if (_presets.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 28),
                  Text(
                    _showVendorLinks
                        ? 'Open a saved vendor app'
                        : 'Saved vendor links (tap Copy instructions first)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...List<Widget>.generate(_presets.length, (int i) {
                    final DonorPreset p = _presets[i];
                    final uri = _orderUri(p.orderUrl);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        key: Key('field_help_open_vendor_$i'),
                        onPressed: (uri != null && _showVendorLinks)
                            ? () => _openPreset(p)
                            : null,
                        icon: const Icon(Icons.open_in_new),
                        label: Text('Open ${p.appName}: ${p.restaurantName}'),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
    );
  }
}
