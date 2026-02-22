import '../../domain/entities/navigation_session.dart';
import '../../domain/entities/session_event.dart';

/// JSON-serializable model matching the SRS Specification 10 format.
class SessionLogModel {
  final String sessionId;
  final String userId;
  final List<Map<String, dynamic>> events;

  const SessionLogModel({
    required this.sessionId,
    required this.userId,
    required this.events,
  });

  factory SessionLogModel.fromSession(NavigationSession session) {
    return SessionLogModel(
      sessionId: session.sessionId,
      userId: session.userId,
      events: session.events.map((e) => e.toJson()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'events': events,
    };
  }

  factory SessionLogModel.fromJson(Map<String, dynamic> json) {
    return SessionLogModel(
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      events: (json['events'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  NavigationSession toDomain() {
    final domainEvents = events.map((e) {
      final typeStr = e['type'] as String;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        e['timestamp'] as int,
        isUtc: true,
      );
      return SessionEvent(type: _parseType(typeStr), timestamp: timestamp);
    }).toList();

    return NavigationSession(
      sessionId: sessionId,
      userId: userId,
      startTime: domainEvents.isNotEmpty
          ? domainEvents.first.timestamp
          : DateTime.now().toUtc(),
      endTime: domainEvents.any((e) => e.type == SessionEventType.arrived)
          ? domainEvents
              .lastWhere((e) => e.type == SessionEventType.arrived)
              .timestamp
          : null,
      events: domainEvents,
    );
  }

  static SessionEventType _parseType(String value) {
    for (final t in SessionEventType.values) {
      if (t.jsonKey == value) return t;
    }
    return SessionEventType.destinationSet;
  }
}
