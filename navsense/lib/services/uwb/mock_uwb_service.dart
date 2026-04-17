import 'dart:async';
import 'dart:math';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';
import 'package:navsense/services/uwb/uwb_service.dart';
import 'package:navsense/services/uwb/uwb_trilateration.dart';

class MockUwbService implements UwbService {
  final StreamController<UwbPosition> _positionStreamController =
      StreamController<UwbPosition>.broadcast();
  final StreamController<UwbConnectionState> _connectionStreamController =
      StreamController<UwbConnectionState>.broadcast();

  Timer? _simulationTimer;
  final Random _random = Random();
  double _simulatedX = 25.0;
  double _simulatedY = 14.5;
  final String _tagId = 'uwb_tag_001';

  late List<UwbAnchor> _anchors;

  MockUwbService() {
    _anchors = UwbPositionCalculator.createDefaultAnchors();
  }

  @override
  Stream<UwbPosition> get positionStream => _positionStreamController.stream;

  @override
  StreamController<UwbConnectionState> get connectionStateStream =>
      _connectionStreamController;

  @override
  bool get isConnected => true;

  @override
  List<UwbAnchor> get anchors => _anchors;

  @override
  UwbPosition? get lastPosition => UwbPosition(
        tagId: _tagId,
        x: _simulatedX,
        y: _simulatedY,
        timestamp: DateTime.now(),
        accuracy: 0.15,
      );

  @override
  double? get lastAccuracy => 0.15;

  @override
  String? get tagId => _tagId;

  @override
  Future<void> connect() async {
    _connectionStreamController.add(UwbConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 500));
    _connectionStreamController.add(UwbConnectionState.connected);
    _startSimulation();
  }

  @override
  Future<void> disconnect() async {
    _stopSimulation();
    _connectionStreamController.add(UwbConnectionState.disconnected);
  }

  @override
  void dispose() {
    _stopSimulation();
    _positionStreamController.close();
    _connectionStreamController.close();
  }

  void _startSimulation() {
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updateSimulatedPosition();
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void _updateSimulatedPosition() {
    _simulatedX += (_random.nextDouble() - 0.5) * 0.3;
    _simulatedY += (_random.nextDouble() - 0.5) * 0.3;

    _simulatedX = _simulatedX.clamp(1.0, 49.0);
    _simulatedY = _simulatedY.clamp(1.0, 28.0);

    _updateAnchorDistances();

    final position = UwbPosition(
      tagId: _tagId,
      x: _simulatedX,
      y: _simulatedY,
      timestamp: DateTime.now(),
      accuracy: 0.15,
    );

    _positionStreamController.add(position);
  }

  void _updateAnchorDistances() {
    _anchors = _anchors.map((anchor) {
      final distance = _calculateDistance(
        _simulatedX,
        _simulatedY,
        anchor.x,
        anchor.y,
      );
      return anchor.copyWith(distanceMeters: distance);
    }).toList();
  }

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    final dx = x2 - x1;
    final dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  Future<void> updateAnchorPosition(
      String anchorId, double x, double y, double z) async {
    final index = _anchors.indexWhere((a) => a.id == anchorId);
    if (index != -1) {
      _anchors[index] = _anchors[index].copyWith(x: x, y: y, z: z);
    }
  }

  void setSimulatedPosition(double x, double y) {
    _simulatedX = x;
    _simulatedY = y;
    _updateAnchorDistances();
  }
}
