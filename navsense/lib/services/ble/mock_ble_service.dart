import 'dart:async';
import 'dart:math';

import '../../core/constants/app_constants.dart';
import 'ble_service.dart';
import 'ibeacon_parser.dart';

/// Simulates BLE scanning and distance streaming without real hardware.
class MockBleService implements BleService {
  static const double _nearThreshold = 3.0;
  static const double _arrivedThreshold = 1.0;

  bool _connected = false;
  int _connectedBeaconCount = 0;
  StreamController<double>? _distanceController;
  StreamController<Map<String, BeaconReading>>? _beaconReadingsController;
  StreamController<ArrivalState>? _arrivalStateController;
  Timer? _distanceTimer;
  Timer? _beaconReadingsTimer;
  double _currentDistance = 15.0;
  ArrivalState _arrivalState = ArrivalState.far;
  final _random = Random();

  @override
  bool get isConnected => _connected;

  @override
  bool get allBeaconsConnected => _connectedBeaconCount >= 4;

  @override
  int get connectedBeaconCount => _connectedBeaconCount;

  @override
  int get lastRssi => _connected ? -62 - _random.nextInt(10) : 0;

  @override
  double? get lastDistanceMeters => _connected ? _currentDistance : null;

  @override
  String get signalStrength {
    if (!_connected) return 'FAR';
    if (_currentDistance < 1.5) return 'VERY CLOSE';
    if (_currentDistance < 4.0) return 'CLOSE';
    if (_currentDistance < 8.0) return 'MEDIUM';
    return 'FAR';
  }

  @override
  Stream<double> get distanceStream {
    _distanceController ??= StreamController<double>.broadcast();
    return _distanceController!.stream;
  }

  @override
  Stream<Map<String, BeaconReading>> get beaconReadingsStream {
    _beaconReadingsController ??=
        StreamController<Map<String, BeaconReading>>.broadcast();
    return _beaconReadingsController!.stream;
  }

  @override
  ArrivalState get arrivalState => _arrivalState;

  @override
  Stream<ArrivalState> get arrivalStateStream {
    _arrivalStateController ??= StreamController<ArrivalState>.broadcast();
    return _arrivalStateController!.stream;
  }

  @override
  Stream<BleDevice> scanDevices() async* {
    await Future.delayed(const Duration(milliseconds: 500));
    for (int i = 1; i <= 4; i++) {
      yield BleDevice(
        id: 'beacon-$i',
        name: 'Beacon-$i',
        rssi: -60 - _random.nextInt(20),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Future<void> connectAll() async {
    if (_connected) return;
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _connectedBeaconCount = 4;
    _startDistanceSimulation();
    _startBeaconReadingsSimulation();
  }

  @override
  Future<void> connect(String deviceId) async {
    if (_connected) return;
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _connectedBeaconCount = 1;
    _startDistanceSimulation();
  }

  void _startDistanceSimulation() {
    if (_distanceTimer != null) return;
    _distanceController ??= StreamController<double>.broadcast();
    _currentDistance = 15.0;

    _distanceTimer = Timer.periodic(AppConstants.bleDistanceInterval, (_) {
      if (!_connected) return;
      // Approach waypoint with slight noise
      _currentDistance =
          (_currentDistance - 0.3 + (_random.nextDouble() * 0.1 - 0.05))
              .clamp(0.0, 30.0);
      // Reached waypoint — reset for next step simulation cycle
      if (_currentDistance <= 0.2) {
        _currentDistance = 8.0 + _random.nextDouble() * 4.0;
      }
      if (!(_distanceController?.isClosed ?? true)) {
        _distanceController!.add(_currentDistance);
      }
      _updateArrivalState();
    });
  }

  void _startBeaconReadingsSimulation() {
    if (_beaconReadingsTimer != null) return;
    _beaconReadingsController ??=
        StreamController<Map<String, BeaconReading>>.broadcast();

    _beaconReadingsTimer =
        Timer.periodic(AppConstants.bleDistanceInterval, (_) {
      if (!_connected) return;
      final readings = <String, BeaconReading>{};
      for (int i = 1; i <= _connectedBeaconCount; i++) {
        final beaconId = 'beacon-$i';
        final distance = 2.0 + _random.nextDouble() * 8.0;
        readings[beaconId] = BeaconReading(
          mac: beaconId,
          uuid: 'mock-uuid-$i',
          major: i * 1000,
          minor: i * 100,
          rssi: -60 - _random.nextInt(20),
          txPower: -59,
          distance: distance,
          strength: distance < 1.5
              ? 'VERY CLOSE'
              : distance < 4.0
                  ? 'CLOSE'
                  : distance < 8.0
                      ? 'MEDIUM'
                      : 'FAR',
        );
      }
      if (!(_beaconReadingsController?.isClosed ?? true)) {
        _beaconReadingsController!.add(readings);
      }
    });
  }

  void _stopDistanceSimulation() {
    _distanceTimer?.cancel();
    _distanceTimer = null;
  }

  void _stopBeaconReadingsSimulation() {
    _beaconReadingsTimer?.cancel();
    _beaconReadingsTimer = null;
  }

  void _updateArrivalState() {
    final newState = _calculateArrivalState();
    if (newState != _arrivalState) {
      _arrivalState = newState;
      _arrivalStateController?.add(_arrivalState);
    }
  }

  ArrivalState _calculateArrivalState() {
    if (_currentDistance <= _arrivedThreshold) {
      return ArrivalState.arrived;
    } else if (_currentDistance <= _nearThreshold) {
      return ArrivalState.near;
    }
    return ArrivalState.far;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _stopDistanceSimulation();
    _stopBeaconReadingsSimulation();
  }

  @override
  void dispose() {
    _connected = false;
    _stopDistanceSimulation();
    _stopBeaconReadingsSimulation();
    _distanceController?.close();
    _distanceController = null;
    _beaconReadingsController?.close();
    _beaconReadingsController = null;
    _arrivalStateController?.close();
    _arrivalStateController = null;
  }
}
