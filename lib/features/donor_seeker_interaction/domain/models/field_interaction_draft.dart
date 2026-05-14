/// In-memory / local persistence model for the donor–seeker field slice (BRD steps 2–5).
///
/// Beneficiaries are not registered users; this record is donor-device state only until
/// backend coordination ships.
class FieldInteractionDraft {
  const FieldInteractionDraft({
    required this.foodIntentConfirmed,
    required this.identificationConsentConfirmed,
    required this.safetyFeelsOk,
    required this.beneficiaryAppearanceNotes,
    required this.beneficiaryPrivacyNotes,
    required this.completedAt,
  });

  final bool foodIntentConfirmed;
  final bool identificationConsentConfirmed;
  final bool safetyFeelsOk;
  final String beneficiaryAppearanceNotes;
  final String beneficiaryPrivacyNotes;
  final DateTime completedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'food_intent_confirmed': foodIntentConfirmed,
      'identification_consent_confirmed': identificationConsentConfirmed,
      'safety_feels_ok': safetyFeelsOk,
      'beneficiary_appearance_notes': beneficiaryAppearanceNotes,
      'beneficiary_privacy_notes': beneficiaryPrivacyNotes,
      'completed_at': completedAt.toUtc().toIso8601String(),
    };
  }

  static FieldInteractionDraft? fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final completedRaw = json['completed_at']?.toString();
    if (completedRaw == null || completedRaw.isEmpty) {
      return null;
    }
    final completed = DateTime.tryParse(completedRaw);
    if (completed == null) {
      return null;
    }
    return FieldInteractionDraft(
      foodIntentConfirmed: json['food_intent_confirmed'] == true,
      identificationConsentConfirmed:
          json['identification_consent_confirmed'] == true,
      safetyFeelsOk: json['safety_feels_ok'] == true,
      beneficiaryAppearanceNotes:
          json['beneficiary_appearance_notes']?.toString() ?? '',
      beneficiaryPrivacyNotes:
          json['beneficiary_privacy_notes']?.toString() ?? '',
      completedAt: completed,
    );
  }
}
