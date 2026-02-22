import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/data/models/session_log_model.dart';
import 'package:navsense/domain/entities/navigation_session.dart';
import 'package:navsense/domain/entities/session_event.dart';
import 'package:navsense/domain/repositories/session_repository.dart';
import 'package:navsense/services/logging/session_logging_service_impl.dart';

// Lightweight in-memory stub — no SharedPreferences needed in tests.
class _InMemorySessionRepository implements SessionRepository {
  final Map<String, NavigationSession> _store = {};

  @override
  Future<String> startSession(String anonymizedUserId) async {
    const id = 'test-session-001';
    _store[id] = NavigationSession(
      sessionId: id,
      userId: anonymizedUserId,
      startTime: DateTime.now().toUtc(),
    );
    return id;
  }

  @override
  Future<void> logEvent(String sessionId, SessionEventType type) async {
    final existing = _store[sessionId]!;
    final event = SessionEvent(
        type: type, timestamp: DateTime.now().toUtc());
    _store[sessionId] = existing.copyWith(
        events: [...existing.events, event]);
  }

  @override
  Future<void> endSession(String sessionId) async {
    final existing = _store[sessionId]!;
    _store[sessionId] =
        existing.copyWith(endTime: DateTime.now().toUtc());
  }

  @override
  Future<NavigationSession?> getSession(String sessionId) async =>
      _store[sessionId];

  @override
  Future<List<NavigationSession>> getAllSessions() async =>
      _store.values.toList();
}

void main() {
  late SessionLoggingServiceImpl service;
  late _InMemorySessionRepository repo;

  setUp(() {
    repo = _InMemorySessionRepository();
    service = SessionLoggingServiceImpl(repo);
  });

  group('SessionLoggingService', () {
    test('startSession returns a non-empty session ID', () async {
      final id = await service.startSession();
      expect(id, isNotEmpty);
    });

    test('logEvent appends event to session', () async {
      final id = await service.startSession();
      await service.logEvent(id, SessionEventType.destinationSet);
      await service.logEvent(id, SessionEventType.routeStarted);

      final session = await service.getSession(id);
      expect(session, isNotNull);
      expect(session!.events.length, 2);
      expect(session.events[0].type, SessionEventType.destinationSet);
      expect(session.events[1].type, SessionEventType.routeStarted);
    });

    test('all SR-LOG-01 event types can be logged', () async {
      final id = await service.startSession();
      final types = [
        SessionEventType.destinationSet,
        SessionEventType.routeComputationStart,
        SessionEventType.routeStarted,
        SessionEventType.turnLeft,
        SessionEventType.turnRight,
        SessionEventType.offRoute,
        SessionEventType.arrived,
      ];
      for (final t in types) {
        await service.logEvent(id, t);
      }
      final session = await service.getSession(id);
      expect(session!.events.length, types.length);
    });

    test('timestamps are stored in UTC', () async {
      final id = await service.startSession();
      await service.logEvent(id, SessionEventType.routeStarted);
      final session = await service.getSession(id);
      for (final e in session!.events) {
        expect(e.timestamp.isUtc, isTrue);
      }
    });

    test('SessionLogModel JSON matches SRS Spec 10 structure', () async {
      final id = await service.startSession();
      await service.logEvent(id, SessionEventType.destinationSet);
      await service.logEvent(id, SessionEventType.arrived);
      await service.endSession(id);

      final session = await service.getSession(id);
      final model = SessionLogModel.fromSession(session!);
      final json = model.toJson();

      expect(json.containsKey('session_id'), isTrue);
      expect(json.containsKey('user_id'), isTrue);
      expect(json.containsKey('events'), isTrue);

      final events = json['events'] as List;
      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.containsKey('type'), isTrue);
        expect(e.containsKey('timestamp'), isTrue);
        expect(e['timestamp'], isA<int>()); // unix epoch millis
      }
    });

    test('endSession does not throw', () async {
      final id = await service.startSession();
      await expectLater(service.endSession(id), completes);
    });

    test('getAllSessions returns previously started sessions', () async {
      await service.startSession();
      final all = await service.getAllSessions();
      expect(all, isNotEmpty);
    });
  });
}
