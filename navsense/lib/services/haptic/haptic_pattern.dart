enum HapticMotor {
  frontLeft,
  frontRight,
  backLeft,
  backRight,
}

enum HapticIntensity {
  light,
  medium,
  strong,
}

class MotorPulse {
  final HapticMotor motor;
  final HapticIntensity intensity;
  final Duration duration;
  final Duration delay;

  const MotorPulse({
    required this.motor,
    required this.intensity,
    this.duration = const Duration(milliseconds: 100),
    this.delay = Duration.zero,
  });
}

class HapticPattern {
  final String name;
  final List<MotorPulse> pulses;

  const HapticPattern({
    required this.name,
    required this.pulses,
  });

  static const turnLeft = HapticPattern(
    name: 'turn_left',
    pulses: [
      MotorPulse(
        motor: HapticMotor.backLeft,
        intensity: HapticIntensity.medium,
        duration: Duration(milliseconds: 80),
      ),
      MotorPulse(
        motor: HapticMotor.frontLeft,
        intensity: HapticIntensity.medium,
        duration: Duration(milliseconds: 80),
        delay: Duration(milliseconds: 120),
      ),
    ],
  );

  static const turnRight = HapticPattern(
    name: 'turn_right',
    pulses: [
      MotorPulse(
        motor: HapticMotor.backRight,
        intensity: HapticIntensity.medium,
        duration: Duration(milliseconds: 80),
      ),
      MotorPulse(
        motor: HapticMotor.frontRight,
        intensity: HapticIntensity.medium,
        duration: Duration(milliseconds: 80),
        delay: Duration(milliseconds: 120),
      ),
    ],
  );

  static const goStraight = HapticPattern(
    name: 'go_straight',
    pulses: [
      MotorPulse(
        motor: HapticMotor.frontLeft,
        intensity: HapticIntensity.light,
        duration: Duration(milliseconds: 60),
      ),
      MotorPulse(
        motor: HapticMotor.frontRight,
        intensity: HapticIntensity.light,
        duration: Duration(milliseconds: 60),
      ),
    ],
  );

  static const arrived = HapticPattern(
    name: 'arrived',
    pulses: [
      MotorPulse(
        motor: HapticMotor.frontLeft,
        intensity: HapticIntensity.strong,
        duration: Duration(milliseconds: 500),
      ),
      MotorPulse(
        motor: HapticMotor.frontRight,
        intensity: HapticIntensity.strong,
        duration: Duration(milliseconds: 500),
      ),
      MotorPulse(
        motor: HapticMotor.backLeft,
        intensity: HapticIntensity.strong,
        duration: Duration(milliseconds: 500),
      ),
      MotorPulse(
        motor: HapticMotor.backRight,
        intensity: HapticIntensity.strong,
        duration: Duration(milliseconds: 500),
      ),
    ],
  );

  static const offRoute = HapticPattern(
    name: 'off_route',
    pulses: [
      MotorPulse(
          motor: HapticMotor.backLeft, intensity: HapticIntensity.strong),
      MotorPulse(
          motor: HapticMotor.backRight, intensity: HapticIntensity.strong),
      MotorPulse(
          motor: HapticMotor.frontLeft, intensity: HapticIntensity.strong),
      MotorPulse(
          motor: HapticMotor.frontRight, intensity: HapticIntensity.strong),
    ],
  );
}
