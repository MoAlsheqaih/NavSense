import 'dart:async';

import 'package:flutter/foundation.dart';
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
  final Set<String> _connectedBeaconIds = {};
  final Map<String, BeaconReading> _lastBeaconReadings = {};

  StreamSubscription<RangingResult>? _rangingSub;
  final _distanceController = StreamController<double>.broadcast();
  final _beaconReadingsController =
      StreamController<Map<String, BeaconReading>>.broadcast();

  @override
  bool get isConnected => _connected;

  @override
  bool get allBeaconsConnected =>
      _connectedBeaconIds.length == BeaconConfig.allBeacons.length;

  @override
  int get connectedBeaconCount => _connectedBeaconIds.length;

  @override
  Stream<double> get distanceStream => _distanceController.stream;

  @override
  Stream<Map<String, BeaconReading>> get beaconReadingsStream =>
      _beaconReadingsController.stream;

  @override
  int get lastRssi => _lastRssi;

  @override
  double? get lastDistanceMeters => _lastDistance;

  @override
  String get signalStrength => _signalStrength;

  /// Not used for iBeacons — ranging starts in connect().
  @override
  Stream<BleDevice> scanDevices() async* {
    for (final beacon in BeaconConfig.allBeacons) {
      yield BleDevice(
        id: beacon.mac,
        name: beacon.name,
        rssi: 0,
      );
    }
  }

  /// Connects to all configured beacons simultaneously.
  @override
  Future<void> connectAll() async {
    if (kIsWeb) {
      // BLE not supported on web
      _connected = false;
      return;
    }
    await flutterBeacon.initializeAndCheckScanning;

    final regions = BeaconConfig.allBeacons
        .map((beacon) => Region(
              identifier: 'navsense_${beacon.name.toLowerCase()}',
              proximityUUID: beacon.uuid,
              major: beacon.major,
              minor: beacon.minor,
            ))
        .toList();

    _rangingSub = flutterBeacon.ranging(regions).listen((result) {
      if (result.beacons.isEmpty) {
        _connected = false;
        _connectedBeaconIds.clear();
        return;
      }

      // Update connected beacons
      _connectedBeaconIds.clear();
      final readings = <String, BeaconReading>{};

      for (final beacon in result.beacons) {
        final beaconId =
            '${beacon.proximityUUID}:${beacon.major}:${beacon.minor}';
        _connectedBeaconIds.add(beaconId);

        final reading = BeaconReading(
          mac:
              beaconId, // Using UUID:major:minor as identifier since MAC not available
          uuid: beacon.proximityUUID,
          major: beacon.major,
          minor: beacon.minor,
          rssi: beacon.rssi,
          txPower: -59, // Default tx power
          distance: beacon.accuracy > 0 ? beacon.accuracy : null,
          strength: _proximityLabel(beacon.proximity),
        );
        readings[beaconId] = reading;
      }

      _connected = _connectedBeaconIds.isNotEmpty;
      _lastBeaconReadings.clear();
      _lastBeaconReadings.addAll(readings);
      _beaconReadingsController.add(Map.from(readings));

      // Aggregate distance from all beacons (use closest)
      final validDistances = readings.values
          .map((r) => r.distance)
          .where((d) => d != null && d > 0)
          .cast<double>();

      if (validDistances.isNotEmpty) {
        _lastDistance = validDistances.reduce((a, b) => a < b ? a : b);
        _lastRssi =
            readings.values.map((r) => r.rssi).reduce((a, b) => a > b ? a : b);
        _signalStrength = _proximityLabelFromDistance(_lastDistance!);
        _distanceController.add(_lastDistance!);
      }
    });
  }

  /// Initialises CoreLocation and starts ranging the target beacon region (legacy single connection).
  @override
  Future<void> connect(String deviceId) async {
    // For backward compatibility, connect to all beacons
    await connectAll();
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
      case Proximity.immediate:
        return 'VERY CLOSE';
      case Proximity.near:
        return 'CLOSE';
      case Proximity.far:
        return 'FAR';
      default:
        return 'MEDIUM';
    }
  }

  /// Maps distance to proximity label (used when aggregating multiple beacons).
  String _proximityLabelFromDistance(double distance) {
    if (distance <= 1.0) return 'VERY CLOSE';
    if (distance <= 3.0) return 'CLOSE';
    if (distance <= 10.0) return 'MEDIUM';
    return 'FAR';
  }
}
