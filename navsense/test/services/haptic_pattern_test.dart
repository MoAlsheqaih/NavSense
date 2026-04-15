import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/services/haptic/haptic_pattern.dart';
import 'package:navsense/services/haptic/mock_wearable_haptic_service.dart';

void main() {
  group('HapticPattern', () {
    test('turnLeft has correct motor sequence', () {
      expect(HapticPattern.turnLeft.name, equals('turn_left'));
      expect(HapticPattern.turnLeft.pulses.length, equals(2));
      expect(
          HapticPattern.turnLeft.pulses[0].motor, equals(HapticMotor.backLeft));
      expect(HapticPattern.turnLeft.pulses[1].motor,
          equals(HapticMotor.frontLeft));
    });

    test('turnRight has correct motor sequence', () {
      expect(HapticPattern.turnRight.name, equals('turn_right'));
      expect(HapticPattern.turnRight.pulses.length, equals(2));
      expect(HapticPattern.turnRight.pulses[0].motor,
          equals(HapticMotor.backRight));
      expect(HapticPattern.turnRight.pulses[1].motor,
          equals(HapticMotor.frontRight));
    });

    test('goStraight uses front motors only', () {
      expect(HapticPattern.goStraight.name, equals('go_straight'));
      expect(HapticPattern.goStraight.pulses.length, equals(2));
      expect(HapticPattern.goStraight.pulses[0].motor,
          equals(HapticMotor.frontLeft));
      expect(HapticPattern.goStraight.pulses[1].motor,
          equals(HapticMotor.frontRight));
    });

    test('arrived uses all four motors', () {
      expect(HapticPattern.arrived.name, equals('arrived'));
      expect(HapticPattern.arrived.pulses.length, equals(4));
      for (final pulse in HapticPattern.arrived.pulses) {
        expect(pulse.intensity, equals(HapticIntensity.strong));
      }
    });
  });

  group('MockWearableHapticService', () {
    late MockWearableHapticService service;

    setUp(() {
      service = MockWearableHapticService();
    });

    test('starts disconnected', () {
      expect(service.isConnected, isFalse);
    });

    test('connects and becomes connected', () async {
      await service.connect();
      expect(service.isConnected, isTrue);
    });

    test('is4MotorWearable returns true', () {
      expect(service.is4MotorWearable, isTrue);
    });

    test('playPattern records pattern name', () async {
      await service.connect();
      await service.playPattern(HapticPattern.turnLeft);
      expect(service.playedPatterns, contains('turn_left'));
    });

    test('triggerDirection plays correct pattern for left', () async {
      await service.connect();
      await service.triggerDirection(TurnDirection.left);
      expect(service.playedPatterns, contains('turn_left'));
    });

    test('triggerDirection plays correct pattern for right', () async {
      await service.connect();
      await service.triggerDirection(TurnDirection.right);
      expect(service.playedPatterns, contains('turn_right'));
    });

    test('triggerDirection plays correct pattern for straight', () async {
      await service.connect();
      await service.triggerDirection(TurnDirection.straight);
      expect(service.playedPatterns, contains('go_straight'));
    });

    test('triggerDirection plays correct pattern for arrived', () async {
      await service.connect();
      await service.triggerDirection(TurnDirection.arrived);
      expect(service.playedPatterns, contains('arrived'));
    });
  });
}
