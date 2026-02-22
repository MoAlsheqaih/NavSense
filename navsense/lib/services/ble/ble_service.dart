/// Abstract BLE service interface.
/// Concrete implementations (mock or real) are injected via GetIt.
abstract class BleService {
  /// Whether BLE is actively connected to the wearable.
  bool get isConnected;

  /// Estimated distance to the next waypoint in meters.
  Stream<double> get distanceStream;

  /// Scans for nearby NavSense wearable devices.
  Stream<BleDevice> scanDevices();

  /// Connects to the wearable with the given [deviceId].
  Future<void> connect(String deviceId);

  /// Disconnects from the current wearable.
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
