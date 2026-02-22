import 'package:uuid/uuid.dart';

import '../../domain/entities/navigation_session.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/session_repository.dart';
import '../datasources/local_session_datasource.dart';
import '../models/session_log_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final LocalSessionDatasource _datasource;
  final _uuid = const Uuid();

  // In-memory cache of the active session during navigation.
  final Map<String, NavigationSession> _activeSessions = {};

  SessionRepositoryImpl(this._datasource);

  @override
  Future<String> startSession(String anonymizedUserId) async {
    final id = _uuid.v4();
    final session = NavigationSession(
      sessionId: id,
      userId: anonymizedUserId,
      startTime: DateTime.now().toUtc(),
      events: const [],
    );
    _activeSessions[id] = session;

    final model = SessionLogModel.fromSession(session);
    await _datasource.saveSession(model);
    return id;
  }

  @override
  Future<void> logEvent(String sessionId, SessionEventType type) async {
    final existing = _activeSessions[sessionId];
    if (existing == null) return;

    final event = SessionEvent(
      type: type,
      timestamp: DateTime.now().toUtc(),
    );
    final updated = existing.copyWith(
      events: [...existing.events, event],
    );
    _activeSessions[sessionId] = updated;

    final model = SessionLogModel.fromSession(updated);
    await _datasource.updateSession(model);
  }

  @override
  Future<void> endSession(String sessionId) async {
    final existing = _activeSessions[sessionId];
    if (existing == null) return;

    final closed = existing.copyWith(endTime: DateTime.now().toUtc());
    _activeSessions.remove(sessionId);

    final model = SessionLogModel.fromSession(closed);
    await _datasource.updateSession(model);
  }

  @override
  Future<NavigationSession?> getSession(String sessionId) async {
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId];
    }
    final model = await _datasource.getSession(sessionId);
    return model?.toDomain();
  }

  @override
  Future<List<NavigationSession>> getAllSessions() async {
    final models = await _datasource.getAllSessions();
    return models.map((m) => m.toDomain()).toList();
  }
}
