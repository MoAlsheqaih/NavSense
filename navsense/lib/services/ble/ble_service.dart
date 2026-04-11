import 'ibeacon_parser.dart';

/// Abstract BLE service interface.
/// Concrete implementations (mock or real) are injected via GetIt.
abstract class BleService {
  /// Whether BLE is actively connected to any beacons.
  bool get isConnected;

  /// Whether all configured beacons are connected.
  bool get allBeaconsConnected;

  /// Number of currently connected beacons.
  int get connectedBeaconCount;

  /// Estimated distance to the next waypoint in meters (aggregated from all beacons).
  Stream<double> get distanceStream;

  /// Last measured RSSI in dBm (0 if no reading yet).
  int get lastRssi;

  /// Last estimated distance in meters (null if no reading yet).
  double? get lastDistanceMeters;

  /// Human-readable signal strength: VERY CLOSE / CLOSE / MEDIUM / FAR.
  String get signalStrength;

  /// Stream of individual beacon readings for advanced navigation.
  Stream<Map<String, BeaconReading>> get beaconReadingsStream;

  /// Scans for nearby NavSense beacons.
  Stream<BleDevice> scanDevices();

  /// Connects to all configured beacons simultaneously.
  Future<void> connectAll();

  /// Connects to the wearable with the given [deviceId] (legacy single connection).
  Future<void> connect(String deviceId);

  /// Disconnects from all beacons.
  Future<void> disconnect();

  /// Dispose resources.
  void dispose();
}

class BleDevice {
  final String id;
  final String name;
  final int rssi; // signal strength in dBm

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });

  /// Signal quality as 0.0–1.0 (derived from RSSI).
  double get signalQuality {
    // RSSI typically ranges from -100 (weak) to -40 (strong)
    const minRssi = -100.0;
    const maxRssi = -40.0;
    return ((rssi - minRssi) / (maxRssi - minRssi)).clamp(0.0, 1.0);
  }
}
