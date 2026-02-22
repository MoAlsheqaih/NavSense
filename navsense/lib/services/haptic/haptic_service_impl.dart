import 'package:flutter/services.dart';

import 'haptic_service.dart';

/// Production haptic service using Flutter's HapticFeedback.
/// Works on both Android and iOS without platform channels.
class HapticServiceImpl implements HapticService {
  @override
  Future<void> triggerLeft() async {
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> triggerRight() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.lightImpact();
  }

  @override
  Future<void> triggerArrival() async {
    await HapticFeedback.heavyImpact();
  }

  @override
  Future<void> triggerOffRoute() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  @override
  Future<void> triggerStraight() async {
    await HapticFeedback.selectionClick();
  }
}
