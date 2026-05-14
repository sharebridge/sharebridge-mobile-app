import 'package:flutter/material.dart';

import '../../data/field_interaction_local_storage.dart';
import '../../domain/models/field_interaction_draft.dart';

/// Donor–seeker interaction MVP screens: trigger framing, consent, safety self-check,
/// beneficiary text capture. Instruction pack, secure photo, and vendor redirect follow
/// in later slices (BRD steps 6–8).
class DonorSeekerInteractionPage extends StatefulWidget {
  const DonorSeekerInteractionPage({super.key});

  @override
  State<DonorSeekerInteractionPage> createState() =>
      _DonorSeekerInteractionPageState();
}

class _DonorSeekerInteractionPageState extends State<DonorSeekerInteractionPage> {
  int _step = 0;

  bool _foodIntent = false;
  bool _identificationConsent = false;
  bool _safetyOk = false;

  final TextEditingController _appearanceController = TextEditingController();
  final TextEditingController _privacyController = TextEditingController();

  FieldInteractionDraft? _lastSaved;

  /// Shown when Continue is blocked (consent / safety gates).
  String? _stepGateMessage;

  @override
  void initState() {
    super.initState();
    _hydrateDraft();
  }

  Future<void> _hydrateDraft() async {
    final draft = await loadFieldInteractionDraft();
    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      _lastSaved = draft;
    });
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    _privacyController.dispose();
    super.dispose();
  }

  void _goNext() {
    setState(() => _stepGateMessage = null);
    if (_step == 1) {
      if (!_foodIntent || !_identificationConsent) {
        setState(() {
          _stepGateMessage =
              'Please confirm both statements above to continue respectfully.';
        });
        return;
      }
    }
    if (_step == 2) {
      if (!_safetyOk) {
        setState(() {
          _stepGateMessage =
              'If it does not feel safe to arrange delivery here, stop — you can try again later.';
        });
        return;
      }
    }
    setState(() {
      _step += 1;
    });
  }

  void _goBack() {
    if (_step <= 0) {
      return;
    }
    setState(() {
      _step -= 1;
    });
  }

  Future<void> _finish() async {
    final draft = FieldInteractionDraft(
      foodIntentConfirmed: _foodIntent,
      identificationConsentConfirmed: _identificationConsent,
      safetyFeelsOk: _safetyOk,
      beneficiaryAppearanceNotes: _appearanceController.text.trim(),
      beneficiaryPrivacyNotes: _privacyController.text.trim(),
      completedAt: DateTime.now().toUtc(),
    );
    await saveFieldInteractionDraft(draft);
    if (!mounted) {
      return;
    }
    setState(() {
      _lastSaved = draft;
    });
    Navigator.of(context).pop();
  }

  void _onPrimaryPressed() {
    if (_step == 3) {
      _finish();
    } else {
      _goNext();
    }
  }

  static const List<String> _stepTitles = <String>[
    'Start here',
    'Consent',
    'Quick safety',
    'Beneficiary details',
  ];

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return const Text(
          'This flow is for when someone has approached you and is asking for '
          'food or essentials — not for changing your saved vendor presets.\n\n'
          'Take your time. You can leave this screen at any point.',
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CheckboxListTile(
              key: const Key('field_flow_consent_food'),
              value: _foodIntent,
              onChanged: (bool? v) {
                setState(() {
                  _foodIntent = v ?? false;
                  _stepGateMessage = null;
                });
              },
              title: const Text(
                'I intend to offer food or essentials through a delivery order — not cash.',
              ),
            ),
            CheckboxListTile(
              key: const Key('field_flow_consent_id'),
              value: _identificationConsent,
              onChanged: (bool? v) {
                setState(() {
                  _identificationConsent = v ?? false;
                  _stepGateMessage = null;
                });
              },
              title: const Text(
                'The person agrees to share limited delivery identification details '
                '(for example a respectful description or photo) so the handover can work.',
              ),
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'SharingBridge will add map- and signal-based checks later. For now, '
              'use your judgment: public lighting, traffic, and whether you feel safe '
              'staying through handover.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              key: const Key('field_flow_safety_ok'),
              value: _safetyOk,
              onChanged: (bool? v) {
                setState(() {
                  _safetyOk = v ?? false;
                  _stepGateMessage = null;
                });
              },
              title: const Text(
                'I believe arranging delivery at this spot is reasonably safe right now.',
              ),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('field_flow_appearance'),
              controller: _appearanceController,
              decoration: const InputDecoration(
                labelText: 'Visible cues for delivery (optional)',
                hintText: 'Example: grey jacket, outside the north entrance',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('field_flow_privacy'),
              controller: _privacyController,
              decoration: const InputDecoration(
                labelText: 'Sensitivity or dignity notes (optional)',
                hintText: 'Anything the courier should say or avoid?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_lastSaved != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                'Last saved: ${_lastSaved!.completedAt.toLocal()}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offer food help'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: <Widget>[
              if (_step > 0)
                TextButton(
                  key: const Key('field_flow_back'),
                  onPressed: _goBack,
                  child: const Text('Back'),
                ),
              if (_step > 0) const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('field_flow_primary'),
                  onPressed: _onPrimaryPressed,
                  child: Text(_step == 3 ? 'Save & close' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: <Widget>[
          Text(
            'Step ${_step + 1} of 4',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _stepTitles[_step],
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          if (_stepGateMessage != null) ...<Widget>[
            Text(
              _stepGateMessage!,
              key: const Key('field_flow_gate_message'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildStepBody(),
        ],
      ),
    );
  }
}
