import 'dart:math';

/// Target beacon identity — mirrors Python BeaconConfig constants.
class BeaconConfig {
  BeaconConfig._();

  static const String targetMac  = 'FD:E6:78:39:FC:F1';
  static const String targetUuid = 'FDA50693-A4E2-4FB1-AFCF-C6EB07647825';
  static const int    targetMajor = 10011;
  static const int    targetMinor = 19641;
  static const String targetName  = 'Holy-IOT';
}

/// Data produced for each detected target advertisement.
class BeaconReading {
  final String  mac;
  final String  uuid;
  final int     major;
  final int     minor;
  final int     rssi;
  final int     txPower;
  final double? distance;
  final String  strength;

  const BeaconReading({
    required this.mac,
    required this.uuid,
    required this.major,
    required this.minor,
    required this.rssi,
    required this.txPower,
    required this.distance,
    required this.strength,
  });
}

/// Parses Apple iBeacon manufacturer data and filters for the target beacon.
/// Mirrors the Python parse_ibeacon / is_target / estimate_distance logic.
class IBeaconParser {
  IBeaconParser._();

  /// Apple company identifier used in manufacturer-specific data.
  static const int _appleCompanyId = 0x004C;

  /// Attempts to parse [manufacturerData] as an iBeacon packet.
  /// Returns a [BeaconReading] if the packet is a valid iBeacon AND matches
  /// the target; otherwise returns null.
  static BeaconReading? parse({
    required Map<int, List<int>> manufacturerData,
    required int    rssi,
    required String mac,
    String?         localName,
  }) {
    final payload = manufacturerData[_appleCompanyId];
    if (payload == null || payload.length < 23) return null;

    // iBeacon type bytes: 0x02 0x15
    if (payload[0] != 0x02 || payload[1] != 0x15) return null;

    final uuid    = _formatUuid(payload.sublist(2, 18));
    final major   = (payload[18] << 8) | payload[19];
    final minor   = (payload[20] << 8) | payload[21];
    // Tx power is a signed byte
    final txPower = payload[22] >= 128 ? payload[22] - 256 : payload[22];

    if (!_isTarget(mac: mac.toUpperCase(), localName: localName ?? '',
                   uuid: uuid, major: major, minor: minor)) {
      return null;
    }

    final distance = _estimateDistance(rssi, txPower);
    return BeaconReading(
      mac:      mac,
      uuid:     uuid,
      major:    major,
      minor:    minor,
      rssi:     rssi,
      txPower:  txPower,
      distance: distance,
      strength: _signalLabel(rssi),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Same priority order as the Python is_target(): MAC → UUID/Major/Minor → name.
  static bool _isTarget({
    required String mac,
    required String localName,
    required String uuid,
    required int    major,
    required int    minor,
  }) {
    if (mac == BeaconConfig.targetMac.toUpperCase()) return true;

    if (uuid.toUpperCase() == BeaconConfig.targetUuid &&
        major == BeaconConfig.targetMajor &&
        minor == BeaconConfig.targetMinor) {
      return true;
    }

    if (localName.trim() == BeaconConfig.targetName) return true;

    return false;
  }

  /// Log-distance path-loss model with n = 2.0 (mirrors Python estimate_distance).
  static double? _estimateDistance(int rssi, int txPower) {
    if (rssi == 0) return null;
    const n = 2.0;
    return pow(10.0, (txPower - rssi) / (10.0 * n)).toDouble();
  }

  /// RSSI thresholds mirror Python signal_label().
  static String _signalLabel(int rssi) {
    if (rssi >= -55) return 'VERY CLOSE';
    if (rssi >= -65) return 'CLOSE';
    if (rssi >= -75) return 'MEDIUM';
    return 'FAR';
  }

  /// Formats 16 raw bytes into the standard 8-4-4-4-12 UUID string.
  static String _formatUuid(List<int> bytes) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
    return '${hex.substring(0,  8)}-'
           '${hex.substring(8,  12)}-'
           '${hex.substring(12, 16)}-'
           '${hex.substring(16, 20)}-'
           '${hex.substring(20, 32)}';
  }
}
