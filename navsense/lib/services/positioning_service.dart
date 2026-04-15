import 'dart:async';
import 'package:navsense/domain/entities/waypoint.dart';
import 'package:navsense/services/ble/ble_service.dart';
import 'package:navsense/services/uwb/uwb_position.dart';
import 'package:navsense/services/uwb/uwb_service.dart';

enum PositioningSource {
  uwb,
  ble,
  fused,
}

class FusedPosition {
  final Waypoint waypoint;
  final PositioningSource source;
  final double confidence;
  final DateTime timestamp;

  const FusedPosition({
    required this.waypoint,
    required this.source,
    required this.confidence,
    required this.timestamp,
  });
}

class PositioningService {
  final UwbService uwbService;
  final BleService bleService;

  StreamSubscription<UwbPosition>? _uwbSub;
  StreamSubscription<ArrivalState>? _bleSub;

  final _positionController = StreamController<FusedPosition>.broadcast();

  Stream<FusedPosition> get positionStream => _positionController.stream;

  FusedPosition? _lastPosition;
  FusedPosition? get lastPosition => _lastPosition;

  PositioningSource _currentSource = PositioningSource.ble;
  PositioningSource get currentSource => _currentSource;

  PositioningService({
    required this.uwbService,
    required this.bleService,
  }) {
    _init();
  }

  void _init() {
    _uwbSub = uwbService.positionStream.listen(_onUwbPosition);
    _bleSub = bleService.arrivalStateStream.listen(_onBleArrivalState);
  }

  void _onUwbPosition(UwbPosition position) {
    _currentSource = PositioningSource.uwb;
    _lastPosition = FusedPosition(
      waypoint: position.toWaypoint(),
      source: PositioningSource.uwb,
      confidence: _calculateUwbConfidence(position.accuracy),
      timestamp: DateTime.now(),
    );
    _positionController.add(_lastPosition!);
  }

  void _onBleArrivalState(ArrivalState state) {
    final confidence = _calculateBleConfidence(state);
    final blePosition = _estimateBlePosition(state);

    if (blePosition != null) {
      _lastPosition = FusedPosition(
        waypoint: blePosition,
        source: PositioningSource.ble,
        confidence: confidence,
        timestamp: DateTime.now(),
      );
      _positionController.add(_lastPosition!);
    }
  }

  double _calculateUwbAccuracy() {
    final pos = uwbService.lastPosition;
    if (pos == null) return 1.0;
    return pos.accuracy;
  }

  double _calculateUwbConfidence(double accuracy) {
    return (1.0 / (1.0 + accuracy)).clamp(0.0, 1.0);
  }

  double _calculateBleConfidence(ArrivalState state) {
    switch (state) {
      case ArrivalState.arrived:
        return 0.95;
      case ArrivalState.near:
        return 0.8;
      case ArrivalState.far:
        return 0.5;
    }
  }

  Waypoint? _estimateBlePosition(ArrivalState state) {
    final distance = bleService.lastDistanceMeters;
    if (distance == null) return null;

    return Waypoint(
      id: 'ble_position',
      name: 'BLE Position',
      floor: 0,
      x: 25.0,
      y: 14.5,
    );
  }

  void dispose() {
    _uwbSub?.cancel();
    _bleSub?.cancel();
    _positionController.close();
  }
}
