import 'dart:async';
import 'dart:math';

import '../../core/constants/app_constants.dart';
import 'ble_service.dart';
import 'ibeacon_parser.dart';

/// Simulates BLE scanning and distance streaming without real hardware.
class MockBleService implements BleService {
  bool _connected = false;
  int _connectedBeaconCount = 0;
  StreamController<double>? _distanceController;
  StreamController<Map<String, BeaconReading>>? _beaconReadingsController;
  Timer? _distanceTimer;
  final _random = Random();

  @override
  bool get isConnected => _connected;

  @override
  bool get allBeaconsConnected =>
      _connectedBeaconCount >= 4; // Simulate 4 beacons

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

  double get _currentDistance =>
      (_distanceTimer != null) ? 5.0 : 15.0; // rough sim value

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
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _connectedBeaconCount = 4; // Simulate connecting to 4 beacons
    _startDistanceSimulation();
    _startBeaconReadingsSimulation();
  }

  @override
  Future<void> connect(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _connectedBeaconCount = 1; // Single connection for backward compatibility
    _startDistanceSimulation();
  }

  void _startBeaconReadingsSimulation() {
    _beaconReadingsController ??=
        StreamController<Map<String, BeaconReading>>.broadcast();

    Timer.periodic(AppConstants.bleDistanceInterval, (_) {
      final readings = <String, BeaconReading>{};
      for (int i = 1; i <= _connectedBeaconCount; i++) {
        final beaconId = 'beacon-$i';
        final distance = 5.0 + _random.nextDouble() * 10.0;
        readings[beaconId] = BeaconReading(
          mac: beaconId,
          uuid: 'mock-uuid-$i',
          major: i * 1000,
          minor: i * 100,
          rssi: -60 - _random.nextInt(20),
          txPower: -59,
          distance: distance,
          strength: distance < 3.0
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

  @override
  Future<void> disconnect() async {
    _connected = false;
    _stopDistanceSimulation();
  }

  void _startDistanceSimulation() {
    _distanceController ??= StreamController<double>.broadcast();
    double currentDistance = 15.0;

    _distanceTimer = Timer.periodic(AppConstants.bleDistanceInterval, (_) {
      // Simulate approaching a waypoint
      currentDistance = (currentDistance - 0.3 + (_random.nextDouble() * 0.2))
          .clamp(0.0, 30.0);
      if (!(_distanceController?.isClosed ?? true)) {
        _distanceController!.add(currentDistance);
      }
    });
  }

  void _stopDistanceSimulation() {
    _distanceTimer?.cancel();
    _distanceTimer = null;
  }

  @override
  void dispose() {
    _stopDistanceSimulation();
    _distanceController?.close();
    _distanceController = null;
    _beaconReadingsController?.close();
    _beaconReadingsController = null;
  }
}
