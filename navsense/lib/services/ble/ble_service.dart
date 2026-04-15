import 'ibeacon_parser.dart';

enum ArrivalState {
  far,
  near,
  arrived,
}

abstract class BleService {
  bool get isConnected;
  bool get allBeaconsConnected;
  int get connectedBeaconCount;
  Stream<double> get distanceStream;
  int get lastRssi;
  double? get lastDistanceMeters;
  String get signalStrength;
  Stream<Map<String, BeaconReading>> get beaconReadingsStream;

  ArrivalState get arrivalState;
  Stream<ArrivalState> get arrivalStateStream;

  Stream<BleDevice> scanDevices();
  Future<void> connectAll();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
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
