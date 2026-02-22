import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/domain/entities/navigation_session.dart';
import 'package:navsense/domain/entities/session_event.dart';

void main() {
  group('NavigationSession', () {
    final t0 = DateTime.utc(2024, 3, 15, 10, 0, 0);
    final t1 = t0.add(const Duration(seconds: 3));
    final t2 = t0.add(const Duration(seconds: 5));
    final t3 = t0.add(const Duration(seconds: 60));

    NavigationSession makeSession(List<SessionEvent> events) {
      return NavigationSession(
        sessionId: 'test-session-id',
        userId: 'anon-user',
        startTime: t0,
        events: events,
      );
    }

    test('events are stored in insertion order', () {
      final session = makeSession([
        SessionEvent(type: SessionEventType.destinationSet, timestamp: t0),
        SessionEvent(type: SessionEventType.routeStarted, timestamp: t1),
        SessionEvent(type: SessionEventType.arrived, timestamp: t3),
      ]);

      expect(session.events[0].type, SessionEventType.destinationSet);
      expect(session.events[1].type, SessionEventType.routeStarted);
      expect(session.events[2].type, SessionEventType.arrived);
    });

    test('timestamps are in ascending order', () {
      final session = makeSession([
        SessionEvent(type: SessionEventType.routeStarted, timestamp: t1),
        SessionEvent(type: SessionEventType.turnLeft, timestamp: t2),
        SessionEvent(type: SessionEventType.arrived, timestamp: t3),
      ]);

      for (int i = 1; i < session.events.length; i++) {
        expect(
          session.events[i].timestamp
              .isAfter(session.events[i - 1].timestamp),
          isTrue,
          reason: 'Event $i should be after event ${i - 1}',
        );
      }
    });

    test('navigationDuration is correct', () {
      final session = makeSession([
        SessionEvent(type: SessionEventType.routeStarted, timestamp: t1),
        SessionEvent(type: SessionEventType.arrived, timestamp: t3),
      ]);

      // t3 (60s) - t1 (3s) = 57s
      expect(session.navigationDuration, const Duration(seconds: 57));
    });

    test('navigationDuration is null when arrived event missing', () {
      final session = makeSession([
        SessionEvent(type: SessionEventType.routeStarted, timestamp: t1),
      ]);
      expect(session.navigationDuration, isNull);
    });

    test('routeCalculationMs is computed correctly', () {
      final session = makeSession([
        SessionEvent(
            type: SessionEventType.routeComputationStart, timestamp: t0),
        SessionEvent(type: SessionEventType.routeStarted, timestamp: t1),
      ]);
      expect(session.routeCalculationMs, 3000);
    });

    test('copyWith preserves unmodified fields', () {
      final original = makeSession([]);
      final updated = original.copyWith(
        endTime: t3,
        events: [
          SessionEvent(type: SessionEventType.arrived, timestamp: t3),
        ],
      );

      expect(updated.sessionId, original.sessionId);
      expect(updated.userId, original.userId);
      expect(updated.endTime, t3);
      expect(updated.events.length, 1);
    });
  });

  group('SessionEvent.toJson', () {
    test('produces SRS-compliant JSON structure', () {
      final timestamp = DateTime.utc(2024, 3, 15, 10, 30, 12);
      final event = SessionEvent(
        type: SessionEventType.turnLeft,
        timestamp: timestamp,
      );

      final json = event.toJson();

      expect(json['type'], 'TURN_LEFT');
      expect(json['timestamp'], timestamp.millisecondsSinceEpoch);
    });

    test('all event types produce correct JSON keys', () {
      final expected = {
        SessionEventType.destinationSet: 'DESTINATION_SET',
        SessionEventType.routeComputationStart: 'ROUTE_COMPUTATION_START',
        SessionEventType.routeStarted: 'ROUTE_STARTED',
        SessionEventType.turnLeft: 'TURN_LEFT',
        SessionEventType.turnRight: 'TURN_RIGHT',
        SessionEventType.offRoute: 'OFF_ROUTE',
        SessionEventType.arrived: 'ARRIVED',
      };

      for (final entry in expected.entries) {
        final event = SessionEvent(
          type: entry.key,
          timestamp: DateTime.now().toUtc(),
        );
        expect(event.toJson()['type'], entry.value,
            reason: '${entry.key} should produce ${entry.value}');
      }
    });
  });
}
