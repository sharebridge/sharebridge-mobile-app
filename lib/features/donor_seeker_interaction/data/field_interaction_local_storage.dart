import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/field_interaction_draft.dart';

const String kFieldInteractionDraftKey = 'sharingbridge_field_interaction_draft_v1';

Future<void> saveFieldInteractionDraft(FieldInteractionDraft draft) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kFieldInteractionDraftKey, jsonEncode(draft.toJson()));
}

Future<FieldInteractionDraft?> loadFieldInteractionDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kFieldInteractionDraftKey);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return FieldInteractionDraft.fromJson(decoded);
  } catch (_) {
    return null;
  }
}

Future<void> clearFieldInteractionDraft() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kFieldInteractionDraftKey);
}
