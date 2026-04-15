import 'dart:async';
import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/services/haptic/haptic_pattern.dart';
import 'package:navsense/services/haptic/wearable_haptic_service.dart';

class MockWearableHapticService implements WearableHapticService {
  bool _connected = false;
  final List<String> _playedPatterns = [];

  @override
  bool get isConnected => _connected;

  @override
  bool get is4MotorWearable => true;

  List<String> get playedPatterns => List.unmodifiable(_playedPatterns);

  @override
  Future<void> connect() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> playPattern(HapticPattern pattern) async {
    _playedPatterns.add(pattern.name);

    final delays = <Duration>[];
    for (final pulse in pattern.pulses) {
      delays.add(pulse.delay + pulse.duration);
    }

    if (delays.isNotEmpty) {
      final totalDuration = delays.reduce((a, b) => Duration(
            milliseconds: a.inMilliseconds + b.inMilliseconds,
          ));
      await Future.delayed(totalDuration);
    }
  }

  @override
  Future<void> triggerDirection(TurnDirection direction) async {
    HapticPattern pattern;
    switch (direction) {
      case TurnDirection.left:
        pattern = HapticPattern.turnLeft;
      case TurnDirection.right:
        pattern = HapticPattern.turnRight;
      case TurnDirection.straight:
        pattern = HapticPattern.goStraight;
      case TurnDirection.arrived:
        pattern = HapticPattern.arrived;
    }
    await playPattern(pattern);
  }
}
