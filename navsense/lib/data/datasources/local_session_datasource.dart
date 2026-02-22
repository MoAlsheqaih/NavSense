import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_log_model.dart';

const _kSessionsKey = 'navsense_sessions';

/// Reads and writes session JSON to local storage (SharedPreferences).
class LocalSessionDatasource {
  Future<List<SessionLogModel>> getAllSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessionsKey) ?? [];
    return raw
        .map((s) => SessionLogModel.fromJson(
            Map<String, dynamic>.from(jsonDecode(s) as Map)))
        .toList()
        .reversed
        .toList(); // newest first
  }

  Future<void> saveSession(SessionLogModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessionsKey) ?? [];
    raw.add(jsonEncode(model.toJson()));
    await prefs.setStringList(_kSessionsKey, raw);
  }

  Future<SessionLogModel?> getSession(String sessionId) async {
    final all = await getAllSessions();
    for (final s in all) {
      if (s.sessionId == sessionId) return s;
    }
    return null;
  }

  Future<void> updateSession(SessionLogModel model) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kSessionsKey) ?? [];
    final updated = raw.map((s) {
      final decoded = Map<String, dynamic>.from(jsonDecode(s) as Map);
      if (decoded['session_id'] == model.sessionId) {
        return jsonEncode(model.toJson());
      }
      return s;
    }).toList();
    await prefs.setStringList(_kSessionsKey, updated);
  }
}
