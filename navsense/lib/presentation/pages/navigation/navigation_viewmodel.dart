import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../domain/entities/route_plan.dart';
import '../../../domain/entities/session_event.dart';
import '../../../domain/entities/waypoint.dart';
import '../../../services/ble/ble_service.dart';
import '../../../services/haptic/haptic_service.dart';
import '../../../services/logging/session_logging_service.dart';
import '../../../services/simulation/simulation_config.dart';
import '../../../services/simulation/simulated_position_provider.dart';

enum NavigationStatus { active, arrived, cancelled }

class NavigationViewModel extends ChangeNotifier {
  final RoutePlan routePlan;
  final BleService _bleService;
  final HapticService _hapticService;
  final SessionLoggingService _loggingService;
  final bool useSimulation;
  SimulatedPositionProvider? _positionProvider;

  NavigationViewModel({
    required this.routePlan,
    required BleService bleService,
    required HapticService hapticService,
    required SessionLoggingService loggingService,
    this.useSimulation = false,
  })  : _bleService = bleService,
        _hapticService = hapticService,
        _loggingService = loggingService;

  String? _sessionId;
  int _currentStepIndex = 0;
  double _currentDistance = 0;
  NavigationStatus _status = NavigationStatus.active;
  String? _lastHapticLabel;
  StreamSubscription<double>? _distanceSub;
  StreamSubscription<Waypoint>? _positionSub;
  Waypoint? _currentPosition;

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
  Waypoint? get currentPosition => _currentPosition;

  double _calculateDistanceToWaypoint(Waypoint from, Waypoint to) {
    return sqrt(pow(to.x - from.x, 2) + pow(to.y - from.y, 2));
  }

  Future<void> initialize() async {
    _sessionId = await _loggingService.startSession();
    await _loggingService.logEvent(
        _sessionId!, SessionEventType.destinationSet);
    await _loggingService.logEvent(
        _sessionId!, SessionEventType.routeComputationStart);
    await _loggingService.logEvent(_sessionId!, SessionEventType.routeStarted);

    if (useSimulation) {
      await _initializeSimulation();
    } else {
      await _initializeBle();
    }

    await _triggerHapticForStep();
  }

  Future<void> _initializeSimulation() async {
    _positionProvider = SimulatedPositionProvider(
      config: SimulationConfig(
        destination: routePlan.destination,
        speed: 0.5,
        updateInterval: 1.0,
        addNoise: true,
        noiseRadius: 0.3,
      ),
    );

    await _positionProvider!.start();

    _positionSub = _positionProvider!.positionStream.listen((position) {
      _currentPosition = position;
      final nextWaypoint = routePlan.steps[_currentStepIndex].waypoint;
      _currentDistance = _calculateDistanceToWaypoint(position, nextWaypoint);
      notifyListeners();

      if (_currentDistance < 1.0 && _status == NavigationStatus.active) {
        _advanceStep();
      }
    });
  }

  Future<void> _initializeBle() async {
    await _bleService.connectAll();

    _distanceSub = _bleService.distanceStream.listen((dist) {
      _currentDistance = dist;
      notifyListeners();

      if (dist < 1.0 && _status == NavigationStatus.active) {
        _advanceStep();
      }
    });
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
    await _positionProvider?.stop();
    _distanceSub?.cancel();
    _positionSub?.cancel();
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
    await _positionProvider?.stop();
    _distanceSub?.cancel();
    _positionSub?.cancel();
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
    _positionSub?.cancel();
    _positionProvider?.dispose();
    _bleService.dispose();
    super.dispose();
  }
}
