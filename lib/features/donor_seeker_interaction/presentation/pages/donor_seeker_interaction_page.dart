import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/api_delivery_instructions_request.dart';
import '../../application/stub_delivery_instructions_request.dart';
import '../../../donor_setup/application/load_presets_usecase.dart';
import '../../../donor_setup/data/auth_context.dart';
import '../../../donor_setup/data/donor_setup_api_exceptions.dart';
import '../../../donor_setup/data/donor_setup_repository_impl.dart';
import '../../../donor_setup/data/http_donor_setup_api_client.dart';
import '../../../donor_setup/domain/models/donor_preset.dart';

/// Async AI instruction request (stub or real HTTP client later).
typedef DeliveryInstructionsRequest = Future<String> Function({
  required List<DonorPreset> presets,
  required bool hasReferencePhoto,
  String? verbalHandoverNotes,
});

/// Picks a reference image from camera or gallery.
typedef ReferencePhotoPick = Future<XFile?> Function(ImageSource source);

enum _OfferHelpStep { guidance, photoAndAi, deliveryReady }

/// Offer food help: dignity guidance → photo + AI instructions → copy and
/// vendor deep links.
class DonorSeekerInteractionPage extends StatefulWidget {
  const DonorSeekerInteractionPage({
    super.key,
    this.loadPresetsUseCase,
    this.authContext,
    this.deliveryInstructionsRequest,
    this.referencePhotoPick,
  });

  final LoadPresetsUseCase? loadPresetsUseCase;
  final AuthContext? authContext;

  /// Override for tests or to plug in a real API client.
  final DeliveryInstructionsRequest? deliveryInstructionsRequest;

  /// Override for tests; default uses [ImagePicker].
  final ReferencePhotoPick? referencePhotoPick;

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
  bool _loadingPresets = true;
  String? _errorText;
  bool _showVendorLinks = false;

  _OfferHelpStep _step = _OfferHelpStep.guidance;
  XFile? _referencePhoto;
  final TextEditingController _verbalNotesController = TextEditingController();
  bool _generatingInstructions = false;

  DeliveryInstructionsRequest get _deliveryRequest =>
      widget.deliveryInstructionsRequest ?? _defaultDeliveryInstructionsRequest;

  Future<String> _defaultDeliveryInstructionsRequest({
    required List<DonorPreset> presets,
    required bool hasReferencePhoto,
    String? verbalHandoverNotes,
  }) {
    return requestDeliveryInstructionsFromApi(
      baseUrl: _defaultApiBaseUrl,
      presets: presets,
      hasReferencePhoto: hasReferencePhoto,
      verbalHandoverNotes: verbalHandoverNotes,
    );
  }

  Future<XFile?> _defaultPick(ImageSource source) {
    return ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
  }

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

  @override
  void dispose() {
    _verbalNotesController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loadingPresets = true;
      _errorText = null;
    });
    try {
      final list = await _loadPresetsUseCase(userId: _authContext.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _presets = list;
        _loadingPresets = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingPresets = false;
        _errorText = _friendlyLoadError(e);
        _presets = <DonorPreset>[];
      });
    }
  }

  String _friendlyLoadError(Object e) {
    if (e is DonorSetupTimeoutException) {
      return 'Could not load presets (timeout). You can still generate instructions and open links if you know them.';
    }
    if (e is DonorSetupNetworkException) {
      return 'Could not load presets (offline). Saved vendor links appear after you reconnect.';
    }
    if (e is DonorSetupServerException) {
      return 'Could not load presets (server error). Try again in a moment.';
    }
    return 'Could not load saved presets.';
  }

  void _goBackWithinFlow() {
    if (_step == _OfferHelpStep.guidance) {
      return;
    }
    setState(() {
      if (_step == _OfferHelpStep.photoAndAi) {
        _step = _OfferHelpStep.guidance;
        _referencePhoto = null;
        _verbalNotesController.clear();
      } else if (_step == _OfferHelpStep.deliveryReady) {
        _step = _OfferHelpStep.photoAndAi;
        _instructions = '';
        _showVendorLinks = false;
      }
    });
  }

  Future<void> _showPickSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }
    await _runPick(source);
  }

  Future<void> _runPick(ImageSource source) async {
    try {
      final pick = widget.referencePhotoPick ?? _defaultPick;
      final XFile? file = await pick(source);
      if (!mounted) {
        return;
      }
      setState(() => _referencePhoto = file);
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access photo: ${e.message ?? e.code}')),
      );
    }
  }

  Future<void> _generateInstructions() async {
    setState(() => _generatingInstructions = true);
    try {
      final text = await _deliveryRequest(
        presets: _presets,
        hasReferencePhoto: _referencePhoto != null,
        verbalHandoverNotes: _verbalNotesController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _instructions = text;
        _generatingInstructions = false;
        _step = _OfferHelpStep.deliveryReady;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _generatingInstructions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not get instructions: $e'),
        ),
      );
    }
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

  String _stepLabel() {
    switch (_step) {
      case _OfferHelpStep.guidance:
        return 'Step 1 of 3 · Guidance';
      case _OfferHelpStep.photoAndAi:
        return 'Step 2 of 3 · Photo and AI';
      case _OfferHelpStep.deliveryReady:
        return 'Step 3 of 3 · Paste in vendor app';
    }
  }

  Widget _buildGuidanceBody(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Quick guidance',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Treat personal details with care: share only what is needed for '
          'the courier to complete the handover with dignity.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Before taking a photo to identify the person receiving help, '
          'ask for their consent. If they prefer not to be photographed, '
          'use a respectful verbal description instead.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        FilledButton(
          key: const Key('field_help_continue_guidance'),
          onPressed: () {
            setState(() => _step = _OfferHelpStep.photoAndAi);
          },
          child: const Text('Continue to photo and instructions'),
        ),
      ],
    );
  }

  Widget _buildPhotoAndAiBody(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Reference photo and AI draft',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Only add a photo if the person has agreed. You can skip the photo '
          'and describe the handover in words below — the next step calls the '
          'instruction service (stub today, API later).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (_generatingInstructions) const LinearProgressIndicator(),
        if (_generatingInstructions) const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('field_help_add_reference_photo'),
          onPressed: _generatingInstructions ? null : _showPickSourceSheet,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            _referencePhoto == null
                ? 'Add reference photo'
                : 'Change reference photo',
          ),
        ),
        if (_referencePhoto != null) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: InputChip(
              label: Text(
                _referencePhoto!.name,
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: _generatingInstructions
                  ? null
                  : () => setState(() => _referencePhoto = null),
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          key: const Key('field_help_verbal_notes'),
          controller: _verbalNotesController,
          enabled: !_generatingInstructions,
          decoration: const InputDecoration(
            labelText: 'Handover notes (optional)',
            hintText:
                'e.g. grey jacket, north gate — or anything the courier should know',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        if (_errorText != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _errorText!,
            style: TextStyle(
              color: colors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const Key('field_help_generate_ai'),
          onPressed: _generatingInstructions ? null : _generateInstructions,
          icon: _generatingInstructions
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_outlined),
          label: Text(
            _generatingInstructions ? 'Getting instructions…' : 'Get AI delivery instructions',
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryReadyBody(ThemeData theme, ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Your delivery text',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Review and edit if needed before copying. This draft was produced '
          'by the instruction service using your presets and the notes or '
          'photo you provided.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Card.filled(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SelectableText(
              _instructions,
              key: const Key('field_help_instruction_body'),
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
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
            style: theme.textTheme.titleMedium,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final Widget body = _loadingPresets
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _stepLabel(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (_step == _OfferHelpStep.guidance)
                  _buildGuidanceBody(theme)
                else if (_step == _OfferHelpStep.photoAndAi)
                  _buildPhotoAndAiBody(theme, colors)
                else
                  _buildDeliveryReadyBody(theme, colors),
              ],
            ),
          );

    return PopScope(
      canPop: _step == _OfferHelpStep.guidance,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _step != _OfferHelpStep.guidance) {
          _goBackWithinFlow();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Offer food help'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: _step == _OfferHelpStep.guidance ? 'Close' : 'Back',
            onPressed: () {
              if (_step == _OfferHelpStep.guidance) {
                Navigator.of(context).maybePop();
              } else {
                _goBackWithinFlow();
              }
            },
          ),
        ),
        body: body,
      ),
    );
  }
}
