import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';
import 'package:navsense/services/uwb/uwb_service.dart';
import 'package:navsense/services/uwb/uwb_trilateration.dart';

class BleUwbService implements UwbService {
  static const String _deviceName = 'UWB-Wearable';
  static const String _nusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String _nusTxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

  static final Map<String, UwbAnchor> _anchorMap = {
    '1782': const UwbAnchor(id: '1782', name: 'A1', x: 0.0, y: 0.0),
    '1783': const UwbAnchor(id: '1783', name: 'A2', x: 5.0, y: 0.0),
    '1781': const UwbAnchor(id: '1781', name: 'A3', x: 5.0, y: 10.0),
  };

  final StreamController<UwbPosition> _positionController =
      StreamController<UwbPosition>.broadcast();
  final StreamController<UwbConnectionState> _connectionController =
      StreamController<UwbConnectionState>.broadcast();

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  static const double _emaAlpha = 0.3; // EMA smoothing factor (0=no update, 1=no smoothing)

  List<UwbAnchor> _anchors = List.unmodifiable(_anchorMap.values.toList());
  UwbPosition? _lastPosition;
  double? _smoothedX;
  double? _smoothedY;
  bool _connected = false;
  final String _tagId = 'uwb_tag_001';
  String? lastError;
  String? lastRawData;

  @override
  Stream<UwbPosition> get positionStream => _positionController.stream;

  @override
  StreamController<UwbConnectionState> get connectionStateStream =>
      _connectionController;

  @override
  bool get isConnected => _connected;

  @override
  List<UwbAnchor> get anchors => _anchors;

  @override
  UwbPosition? get lastPosition => _lastPosition;

  @override
  double? get lastAccuracy => _lastPosition?.accuracy;

  @override
  String? get tagId => _tagId;

  @override
  Future<void> connect() async {
    _connectionController.add(UwbConnectionState.connecting);
    try {
      await _scanAndConnect();
    } catch (e) {
      _connected = false;
      lastError = e.toString();
      _connectionController.add(UwbConnectionState.error);
      rethrow;
    }
  }

  Future<void> _scanAndConnect() async {
    // Wait until Bluetooth is fully on
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Bluetooth not available — enable Bluetooth'));

    // Check system-connected devices first (already paired via iOS Settings)
    try {
      final systemDevices = await FlutterBluePlus.systemDevices(
          [Guid(_nusServiceUuid)]);
      for (final device in systemDevices) {
        if (device.platformName == _deviceName) {
          _device = device;
          await _setupDevice(device);
          return;
        }
      }
    } catch (_) {
      // systemDevices may fail on some OS versions — fall through to scan
    }

    // Fall back to scanning
    final completer = Completer<BluetoothDevice>();
    StreamSubscription? scanSub;

    scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _deviceName && !completer.isCompleted) {
          completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(
      withNames: [_deviceName],
      timeout: const Duration(seconds: 10),
    );

    try {
      final device = await completer.future
          .timeout(const Duration(seconds: 12),
              onTimeout: () => throw Exception('UWB-Wearable not found — '
                  'make sure the ESP32 is on and in range'));
      await FlutterBluePlus.stopScan();
      _device = device;
      await _setupDevice(device);
    } finally {
      await scanSub.cancel();
    }
  }

  Future<void> _setupDevice(BluetoothDevice device) async {
    // Connect only if not already connected
    final state = await device.connectionState.first;
    if (state != BluetoothConnectionState.connected) {
      await device.connect(autoConnect: false);
    }

    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _connected = false;
        _connectionController.add(UwbConnectionState.disconnected);
      }
    });

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() == _nusServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _nusTxUuid) {
            await char.setNotifyValue(true);
            _notifySub = char.onValueReceived.listen(_onData);
            _connected = true;
            _connectionController.add(UwbConnectionState.connected);
            return;
          }
        }
      }
    }

    throw Exception('NUS TX characteristic not found on UWB-Wearable');
  }

  void _onData(List<int> data) {
    if (data.isEmpty) return;
    lastRawData = utf8.decode(data, allowMalformed: true);
    debugPrint('[UWB] Raw: $lastRawData');
    try {
      final json = jsonDecode(lastRawData!) as Map<String, dynamic>;
      final links = json['links'] as List<dynamic>?;
      if (links == null || links.isEmpty) return;

      final updatedAnchors = <UwbAnchor>[];
      for (final link in links) {
        final addr = _normalizeAddr(link['A'] as String? ?? '');
        final rawR = link['R'];
        final range = rawR is num
            ? rawR.toDouble()
            : double.tryParse(rawR?.toString() ?? '');
        if (range == null) continue;
        final anchor = _anchorMap[addr];
        if (anchor != null) {
          updatedAnchors.add(anchor.copyWith(distanceMeters: range));
        }
      }

      if (updatedAnchors.length < 2) return;

      _anchors = List.unmodifiable(
        _anchorMap.values.map((a) {
          final updated = updatedAnchors.firstWhere(
            (u) => u.id == a.id,
            orElse: () => a,
          );
          return updated;
        }).toList(),
      );

      final position = UwbPositionCalculator.calculatePosition(
        anchors: updatedAnchors,
        tagId: _tagId,
      );

      if (position != null) {
        // EMA smoothing: seed with first reading, then blend
        if (_smoothedX == null || _smoothedY == null) {
          _smoothedX = position.x;
          _smoothedY = position.y;
        } else {
          _smoothedX = _emaAlpha * position.x + (1 - _emaAlpha) * _smoothedX!;
          _smoothedY = _emaAlpha * position.y + (1 - _emaAlpha) * _smoothedY!;
        }

        _lastPosition = UwbPosition(
          tagId: _tagId,
          x: _smoothedX!,
          y: _smoothedY!,
          timestamp: DateTime.now(),
          accuracy: position.accuracy,
        );
        _positionController.add(_lastPosition!);
      }
    } catch (_) {}
  }

  String _normalizeAddr(String addr) =>
      addr.trim().toUpperCase().replaceAll('0X', '');

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _notifySub?.cancel();
    await _connStateSub?.cancel();
    _notifySub = null;
    _connStateSub = null;
    await _device?.disconnect();
    _device = null;
    _connectionController.add(UwbConnectionState.disconnected);
  }

  @override
  void dispose() {
    disconnect();
    _positionController.close();
    _connectionController.close();
  }

  @override
  Future<void> updateAnchorPosition(
      String anchorId, double x, double y, double z) async {
    _anchorMap[anchorId] = _anchorMap[anchorId]!.copyWith(x: x, y: y, z: z);
  }
}
