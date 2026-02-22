import '../../domain/entities/navigation_session.dart';
import '../../domain/entities/session_event.dart';

/// Abstract session logging service (SR-LOG-01).
abstract class SessionLoggingService {
  /// Starts a new session. Returns the session ID.
  Future<String> startSession();

  /// Logs an event to the active session.
  Future<void> logEvent(String sessionId, SessionEventType type);

  /// Closes the session.
  Future<void> endSession(String sessionId);

  /// Returns the full session as a domain entity (for JSON export).
  Future<NavigationSession?> getSession(String sessionId);

  /// Returns all sessions, newest first.
  Future<List<NavigationSession>> getAllSessions();
}
