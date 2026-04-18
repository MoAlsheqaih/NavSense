import 'dart:async';
import 'dart:io';
import 'package:navsense/core/constants/app_constants.dart';
import 'package:navsense/domain/entities/route_plan.dart';
import 'package:navsense/services/haptic/haptic_pattern.dart';
import 'package:navsense/services/haptic/wearable_haptic_service.dart';

class UdpWearableHapticService implements WearableHapticService {
  RawDatagramSocket? _socket;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  bool get is4MotorWearable => true;

  @override
  Future<void> connect() async {
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _connected = true;
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _socket?.close();
    _socket = null;
    _connected = false;
  }

  @override
  Future<void> playPattern(HapticPattern pattern) async {
    // For UDP, we only support simple direction commands
    // Complex patterns are not supported via UDP gateway
    // This could be extended if needed
  }

  @override
  Future<void> triggerDirection(TurnDirection direction) async {
    if (!_connected || _socket == null) return;

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
        return;
    }

    _socket!.send(
      cmd.codeUnits,
      InternetAddress.loopbackIPv4,
      AppConstants.hapticGatewayPort,
    );
    print('Sent haptic command: $cmd');
    }
}
