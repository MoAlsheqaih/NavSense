import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/services/haptic/haptic_pattern.dart';

abstract class WearableHapticService {
  bool get isConnected;
  bool get is4MotorWearable => true;

  Future<void> connect();
  Future<void> disconnect();
  Future<void> playPattern(HapticPattern pattern);
  Future<void> triggerDirection(TurnDirection direction);
}
