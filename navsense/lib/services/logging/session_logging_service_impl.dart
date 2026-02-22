import '../../domain/entities/navigation_session.dart';
import '../../domain/entities/session_event.dart';
import '../../domain/repositories/session_repository.dart';
import 'session_logging_service.dart';

class SessionLoggingServiceImpl implements SessionLoggingService {
  final SessionRepository _repository;

  const SessionLoggingServiceImpl(this._repository);

  @override
  Future<String> startSession() {
    return _repository.startSession('anon-user');
  }

  @override
  Future<void> logEvent(String sessionId, SessionEventType type) {
    return _repository.logEvent(sessionId, type);
  }

  @override
  Future<void> endSession(String sessionId) {
    return _repository.endSession(sessionId);
  }

  @override
  Future<NavigationSession?> getSession(String sessionId) {
    return _repository.getSession(sessionId);
  }

  @override
  Future<List<NavigationSession>> getAllSessions() {
    return _repository.getAllSessions();
  }
}
