import '../entities/session_event.dart';
import '../repositories/session_repository.dart';

class LogEventUseCase {
  final SessionRepository _repository;

  const LogEventUseCase(this._repository);

  Future<void> call(String sessionId, SessionEventType type) {
    return _repository.logEvent(sessionId, type);
  }
}
