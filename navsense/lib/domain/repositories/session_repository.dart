import '../entities/navigation_session.dart';
import '../entities/session_event.dart';

/// Abstract contract for session persistence.
abstract class SessionRepository {
  /// Starts a new session and returns its ID.
  Future<String> startSession(String anonymizedUserId);

  /// Appends an event to the active session.
  Future<void> logEvent(String sessionId, SessionEventType type);

  /// Closes the active session.
  Future<void> endSession(String sessionId);

  /// Retrieves a single session by ID.
  Future<NavigationSession?> getSession(String sessionId);

  /// Returns all stored sessions, newest first.
  Future<List<NavigationSession>> getAllSessions();
}
