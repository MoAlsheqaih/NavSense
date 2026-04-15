import 'dart:async';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';

enum UwbConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

abstract class UwbService {
  final StreamController<UwbPosition> _positionStreamController =
      StreamController<UwbPosition>.broadcast();

  Stream<UwbPosition> get positionStream => _positionStreamController.stream;

  StreamController<UwbConnectionState> get connectionStateStream =>
      _connectionStreamController;
  final StreamController<UwbConnectionState> _connectionStreamController =
      StreamController<UwbConnectionState>.broadcast();

  bool get isConnected;
  List<UwbAnchor> get anchors;
  UwbPosition? get lastPosition;
  double? get lastAccuracy;
  String? get tagId;

  Future<void> connect();
  Future<void> disconnect();
  void dispose();

  Future<void> updateAnchorPosition(
      String anchorId, double x, double y, double z);
}

class UwbDevice {
  final String id;
  final String name;
  final bool isAnchor;

  const UwbDevice({
    required this.id,
    required this.name,
    required this.isAnchor,
  });
}
