import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/entities/route_plan.dart';
import '../../../domain/entities/session_event.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/haptic/haptic_service.dart';
import '../../../services/logging/session_logging_service.dart';

enum NavigationStatus { active, arrived, cancelled }

class NavigationViewModel extends ChangeNotifier {
  final RoutePlan routePlan;
  final BleService _bleService;
  final HapticService _hapticService;
  final SessionLoggingService _loggingService;

  NavigationViewModel({
    required this.routePlan,
    required BleService bleService,
    required HapticService hapticService,
    required SessionLoggingService loggingService,
  })  : _bleService = bleService,
        _hapticService = hapticService,
        _loggingService = loggingService;

  String? _sessionId;
  int _currentStepIndex = 0;
  double _currentDistance = 0;
  NavigationStatus _status = NavigationStatus.active;
  String? _lastHapticLabel;
  StreamSubscription<double>? _distanceSub;

  String? get sessionId => _sessionId;
  int get currentStepIndex => _currentStepIndex;
  double get currentDistance => _currentDistance;
  NavigationStatus get status => _status;
  String? get lastHapticLabel => _lastHapticLabel;
  bool get isConnected => _bleService.isConnected;
  int get lastRssi => _bleService.lastRssi;
  double? get lastDistanceMeters => _bleService.lastDistanceMeters;
  String get signalStrength => _bleService.signalStrength;

  RouteStep get currentStep => routePlan.steps[_currentStepIndex];
  int get totalSteps => routePlan.steps.length;

  Future<void> initialize() async {
    _sessionId = await _loggingService.startSession();
    await _loggingService.logEvent(
        _sessionId!, SessionEventType.destinationSet);
    await _loggingService.logEvent(
        _sessionId!, SessionEventType.routeComputationStart);
    await _loggingService.logEvent(_sessionId!, SessionEventType.routeStarted);

    // Connect BLE wearable
    await _bleService.connect('mock-device-001');

    _distanceSub = _bleService.distanceStream.listen((dist) {
      _currentDistance = dist;
      notifyListeners();

      // Auto-advance step when close enough
      if (dist < 1.0 && _status == NavigationStatus.active) {
        _advanceStep();
      }
    });

    await _triggerHapticForStep();
  }

  Future<void> _advanceStep() async {
    if (_currentStepIndex >= routePlan.steps.length - 1) {
      await _arrive();
      return;
    }
    _currentStepIndex++;
    notifyListeners();

    final step = routePlan.steps[_currentStepIndex];
    if (step.direction == TurnDirection.arrived) {
      await _arrive();
    } else {
      await _logTurnEvent(step.direction);
      await _triggerHapticForStep();
    }
  }

  Future<void> advanceManually() => _advanceStep();

  Future<void> _arrive() async {
    _status = NavigationStatus.arrived;
    if (_sessionId != null) {
      await _loggingService.logEvent(_sessionId!, SessionEventType.arrived);
      await _loggingService.endSession(_sessionId!);
    }
    await _bleService.disconnect();
    _distanceSub?.cancel();
    _lastHapticLabel = 'hapticArrival';
    await _hapticService.triggerArrival();
    notifyListeners();
  }

  Future<void> triggerOffRoute() async {
    if (_sessionId != null) {
      await _loggingService.logEvent(_sessionId!, SessionEventType.offRoute);
    }
    _lastHapticLabel = 'hapticOffRoute';
    await _hapticService.triggerOffRoute();
    notifyListeners();
  }

  Future<void> cancelNavigation() async {
    _status = NavigationStatus.cancelled;
    if (_sessionId != null) {
      await _loggingService.endSession(_sessionId!);
    }
    await _bleService.disconnect();
    _distanceSub?.cancel();
    notifyListeners();
  }

  Future<void> _triggerHapticForStep() async {
    final step = routePlan.steps[_currentStepIndex];
    switch (step.direction) {
      case TurnDirection.left:
        _lastHapticLabel = 'hapticLeft';
        await _hapticService.triggerLeft();
        break;
      case TurnDirection.right:
        _lastHapticLabel = 'hapticRight';
        await _hapticService.triggerRight();
        break;
      case TurnDirection.arrived:
        _lastHapticLabel = 'hapticArrival';
        await _hapticService.triggerArrival();
        break;
      case TurnDirection.straight:
        _lastHapticLabel = null;
        await _hapticService.triggerStraight();
        break;
    }
    notifyListeners();
  }

  Future<void> _logTurnEvent(TurnDirection direction) async {
    if (_sessionId == null) return;
    final type = direction == TurnDirection.left
        ? SessionEventType.turnLeft
        : SessionEventType.turnRight;
    await _loggingService.logEvent(_sessionId!, type);
  }

  @override
  void dispose() {
    _distanceSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
