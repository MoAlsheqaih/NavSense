import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';
import 'package:navsense/services/uwb/uwb_service.dart';
import 'package:navsense/services/uwb/uwb_trilateration.dart';
import 'package:navsense/core/constants/app_constants.dart';

/// Real UWB service that receives position data from ESP32 UWB Pro wearable.
/// Communication: UDP over WiFi.
class RealUwbService implements UwbService {
  final StreamController<UwbPosition> _positionStreamController =
      StreamController<UwbPosition>.broadcast();
  final StreamController<UwbConnectionState> _connectionStreamController =
      StreamController<UwbConnectionState>.broadcast();

  RawDatagramSocket? _udpSocket;
  List<UwbAnchor> _anchors = [];
  String _tagId = 'uwb_tag_001';
  UwbPosition? _lastPosition;
  bool _isListening = false;

  RealUwbService() {
    _anchors = UwbPositionCalculator.createDefaultAnchors(
      floorWidth: AppConstants.floorWidthMeters,
      floorHeight: AppConstants.floorHeightMeters,
    );
  }

  @override
  Stream<UwbPosition> get positionStream => _positionStreamController.stream;

  @override
  StreamController<UwbConnectionState> get connectionStateStream =>
      _connectionStreamController;

  @override
  bool get isConnected => _isListening;

  @override
  List<UwbAnchor> get anchors => List.unmodifiable(_anchors);

  @override
  UwbPosition? get lastPosition => _lastPosition;

  @override
  double? get lastAccuracy => _lastPosition?.accuracy;

  @override
  String? get tagId => _tagId;

  @override
  Future<void> connect() async {
    _connectionStreamController.add(UwbConnectionState.connecting);

    try {
      await _startUdpListener(AppConstants.uwbListenPort);
      _isListening = true;
      _connectionStreamController.add(UwbConnectionState.connected);
    } catch (e) {
      _connectionStreamController.add(UwbConnectionState.error);
      rethrow;
    }
  }

  Future<void> _startUdpListener(int port) async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            _processUwbData(datagram.data);
          }
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  void _processUwbData(List<int> data) {
    try {
      final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
      _tagId = json['tagId'] as String? ?? _tagId;
      final x = (json['x'] as num?)?.toDouble() ?? 0.0;
      final y = (json['y'] as num?)?.toDouble() ?? 0.0;
      final z = (json['z'] as num?)?.toDouble() ?? 0.0;
      final accuracy = (json['accuracy'] as num?)?.toDouble() ?? 0.5;

      _lastPosition = UwbPosition(
        tagId: _tagId,
        x: x,
        y: y,
        z: z,
        timestamp: DateTime.now(),
        accuracy: accuracy,
      );

      final anchorsData = json['anchors'] as List<dynamic>?;
      if (anchorsData != null) {
        _updateAnchorDistances(anchorsData);
      }

      _positionStreamController.add(_lastPosition!);
    } catch (e) {
      // Silent fail for malformed packets
    }
  }

  void _updateAnchorDistances(List<dynamic> anchorsData) {
    _anchors = _anchors.map((anchor) {
      try {
        final data = anchorsData.firstWhere((a) => a['id'] == anchor.id);
        return anchor.copyWith(
            distanceMeters: (data['distance'] as num).toDouble());
      } catch (_) {
        return anchor;
      }
    }).toList();
  }

  @override
  Future<void> disconnect() async {
    _isListening = false;
    final socket = _udpSocket;
    _udpSocket = null;
    if (socket != null) {
      socket.close();
    }
    _connectionStreamController.add(UwbConnectionState.disconnected);
  }

  @override
  void dispose() {
    _isListening = false;
    _udpSocket?.close();
    _udpSocket = null;
    _positionStreamController.close();
    _connectionStreamController.close();
  }

  @override
  Future<void> updateAnchorPosition(
      String anchorId, double x, double y, double z) async {
    final index = _anchors.indexWhere((a) => a.id == anchorId);
    if (index != -1) {
      _anchors[index] = _anchors[index].copyWith(x: x, y: y, z: z);
    }
  }
}
