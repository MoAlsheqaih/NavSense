import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:navsense/core/constants/app_constants.dart';
import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/services/haptic/haptic_pattern.dart';
import 'package:navsense/services/haptic/wearable_haptic_service.dart';

class BleWearableHapticService implements WearableHapticService {
  static const String _deviceName = 'UWB-Wearable';
  static final Guid _nusServiceUuid =
      Guid('6E400001-B5A3-F393-E0A9-E50E24DCCA9E');
  static final Guid _rxCharUuid = Guid('6E400002-B5A3-F393-E0A9-E50E24DCCA9E');

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  bool _connected = false;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;

  @override
  bool get isConnected => _connected;

  @override
  bool get is4MotorWearable => true;

  @override
  Future<void> connect() async {
    await FlutterBluePlus.adapterState
        .where((s) => s == BluetoothAdapterState.on)
        .first
        .timeout(const Duration(seconds: 10),
            onTimeout: () => throw Exception('Bluetooth not available'));

    try {
      final systemDevices =
          await FlutterBluePlus.systemDevices([_nusServiceUuid]);
      for (final device in systemDevices) {
        if (device.platformName == _deviceName ||
            device.platformName == AppConstants.mockDeviceName) {
          _device = device;
          await _setupDevice(device);
          return;
        }
      }
    } catch (_) {}

    final completer = Completer<BluetoothDevice>();
    StreamSubscription? scanSub;

    scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == _deviceName ||
            r.device.platformName == AppConstants.mockDeviceName) {
          completer.complete(r.device);
        }
      }
    });

    await FlutterBluePlus.startScan(
      withNames: [_deviceName],
      timeout: const Duration(seconds: 10),
    );

    try {
      final device = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Wearable not found'),
      );
      await FlutterBluePlus.stopScan();
      _device = device;
      await _setupDevice(device);
    } finally {
      await scanSub.cancel();
    }
  }

  Future<void> _setupDevice(BluetoothDevice device) async {
    final state = await device.connectionState.first;
    if (state != BluetoothConnectionState.connected) {
      await device.connect(autoConnect: false);
    }

    _connStateSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _connected = false;
      }
    });

    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid == _nusServiceUuid) {
        for (final char in service.characteristics) {
          if (char.uuid == _rxCharUuid && char.properties.write) {
            _rxChar = char;
            _connected = true;
            return;
          }
        }
      }
    }

    throw Exception('NUS RX characteristic not found');
  }

  @override
  Future<void> disconnect() async {
    await _connStateSub?.cancel();
    _connStateSub = null;
    await _device?.disconnect();
    _device = null;
    _rxChar = null;
    _connected = false;
  }

  @override
  Future<void> playPattern(HapticPattern pattern) async {
    if (pattern == HapticPattern.turnLeft) {
      await triggerDirection(TurnDirection.left);
    } else if (pattern == HapticPattern.turnRight) {
      await triggerDirection(TurnDirection.right);
    } else if (pattern == HapticPattern.goStraight) {
      await triggerDirection(TurnDirection.straight);
    }
  }

  @override
  Future<void> triggerDirection(TurnDirection direction) async {
    if (!_connected || _rxChar == null) return;

    String? cmd;
    switch (direction) {
      case TurnDirection.left:
        cmd = 'L';
      case TurnDirection.right:
        cmd = 'R';
      case TurnDirection.straight:
        cmd = 'F';
      case TurnDirection.turnAround:
        cmd = 'U';
      case TurnDirection.arrived:
        cmd = 'S';
    }

    await _rxChar!.write(cmd.codeUnits);
    debugPrint('[BLE HAPTIC] Sent: $cmd');
  }
}
