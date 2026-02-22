/// Abstract haptic feedback interface.
/// Localizable labels are passed from the presentation layer.
abstract class HapticService {
  /// Single short pulse — turn left instruction.
  Future<void> triggerLeft();

  /// Two short pulses — turn right instruction.
  Future<void> triggerRight();

  /// Long pulse — arrival at destination.
  Future<void> triggerArrival();

  /// Rapid alternating pulses — off-route alert.
  Future<void> triggerOffRoute();

  /// Straight-ahead confirmation pulse.
  Future<void> triggerStraight();
}
