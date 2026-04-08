import 'dart:async';

import 'package:flutter_beacon/flutter_beacon.dart';

import 'ble_service.dart';
import 'ibeacon_parser.dart';

/// Real BLE service using CoreLocation beacon ranging (iOS).
/// flutter_beacon uses CLBeaconRegion which is the correct iOS API
/// for iBeacon detection — CoreBluetooth strips iBeacon data on iOS.
class RealBleService implements BleService {
  bool _connected = false;
  int _lastRssi = 0;
  double? _lastDistance;
  String _signalStrength = 'FAR';

  StreamSubscription<RangingResult>? _rangingSub;
  final _distanceController = StreamController<double>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  Stream<double> get distanceStream => _distanceController.stream;

  @override
  int get lastRssi => _lastRssi;

  @override
  double? get lastDistanceMeters => _lastDistance;

  @override
  String get signalStrength => _signalStrength;

  /// Not used for iBeacons — ranging starts in connect().
  @override
  Stream<BleDevice> scanDevices() async* {
    yield BleDevice(
      id: BeaconConfig.targetMac,
      name: BeaconConfig.targetName,
      rssi: 0,
    );
  }

  /// Initialises CoreLocation and starts ranging the target beacon region.
  @override
  Future<void> connect(String deviceId) async {
    await flutterBeacon.initializeAndCheckScanning;

    final region = Region(
      identifier: 'navsense_target',
      proximityUUID: BeaconConfig.targetUuid,
      major: BeaconConfig.targetMajor,
      minor: BeaconConfig.targetMinor,
    );

    _rangingSub = flutterBeacon.ranging([region]).listen((result) {
      if (result.beacons.isEmpty) {
        _connected = false;
        return;
      }

      final beacon = result.beacons.first;
      _connected   = true;
      _lastRssi    = beacon.rssi;
      _lastDistance = beacon.accuracy > 0 ? beacon.accuracy : null;
      _signalStrength = _proximityLabel(beacon.proximity);

      if (_lastDistance != null) {
        _distanceController.add(_lastDistance!);
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _rangingSub?.cancel();
    _rangingSub = null;
  }

  @override
  void dispose() {
    disconnect();
    _distanceController.close();
  }

  /// Maps CoreLocation proximity to the same labels used by IBeaconParser.
  String _proximityLabel(Proximity proximity) {
    switch (proximity) {
      case Proximity.immediate: return 'VERY CLOSE';
      case Proximity.near:      return 'CLOSE';
      case Proximity.far:       return 'FAR';
      default:                  return 'MEDIUM';
    }
  }
}
