import 'session_event.dart';

class NavigationSession {
  final String sessionId;
  final String userId; // anonymized
  final DateTime startTime;
  final DateTime? endTime;
  final List<SessionEvent> events;

  const NavigationSession({
    required this.sessionId,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.events = const [],
  });

  NavigationSession copyWith({
    DateTime? endTime,
    List<SessionEvent>? events,
  }) {
    return NavigationSession(
      sessionId: sessionId,
      userId: userId,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      events: events ?? this.events,
    );
  }

  /// Duration from ROUTE_STARTED to ARRIVED, or null if not complete.
  Duration? get navigationDuration {
    final start = events
        .where((e) => e.type == SessionEventType.routeStarted)
        .map((e) => e.timestamp)
        .cast<DateTime?>()
        .firstWhere((_) => true, orElse: () => null);
    final end = events
        .where((e) => e.type == SessionEventType.arrived)
        .map((e) => e.timestamp)
        .cast<DateTime?>()
        .firstWhere((_) => true, orElse: () => null);
    if (start == null || end == null) return null;
    return end.difference(start);
  }

  /// Millis between ROUTE_COMPUTATION_START and ROUTE_STARTED.
  int? get routeCalculationMs {
    final compStart = events
        .where((e) => e.type == SessionEventType.routeComputationStart)
        .map((e) => e.timestamp)
        .cast<DateTime?>()
        .firstWhere((_) => true, orElse: () => null);
    final routeStart = events
        .where((e) => e.type == SessionEventType.routeStarted)
        .map((e) => e.timestamp)
        .cast<DateTime?>()
        .firstWhere((_) => true, orElse: () => null);
    if (compStart == null || routeStart == null) return null;
    return routeStart.difference(compStart).inMilliseconds;
  }
}
