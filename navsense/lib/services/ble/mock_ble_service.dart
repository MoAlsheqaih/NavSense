import 'dart:async';
import 'dart:math';

import '../../core/constants/app_constants.dart';
import 'ble_service.dart';

/// Simulates BLE scanning and distance streaming without real hardware.
class MockBleService implements BleService {
  bool _connected = false;
  StreamController<double>? _distanceController;
  Timer? _distanceTimer;
  final _random = Random();

  @override
  bool get isConnected => _connected;

  @override
  Stream<double> get distanceStream {
    _distanceController ??= StreamController<double>.broadcast();
    return _distanceController!.stream;
  }

  @override
  Stream<BleDevice> scanDevices() async* {
    await Future.delayed(const Duration(milliseconds: 500));
    yield BleDevice(
      id: 'mock-device-001',
      name: AppConstants.mockDeviceName,
      rssi: -60 - _random.nextInt(20),
    );
    await Future.delayed(const Duration(seconds: 1));
    yield BleDevice(
      id: 'mock-device-002',
      name: 'NavSense-Wearable-2',
      rssi: -80 - _random.nextInt(15),
    );
  }

  @override
  Future<void> connect(String deviceId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _startDistanceSimulation();
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
  }
}
