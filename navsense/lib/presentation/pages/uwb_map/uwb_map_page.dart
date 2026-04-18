import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/corridor_map.dart';
import '../../../domain/entities/route_plan.dart';
import '../../../services/haptic/wearable_haptic_service.dart';
import '../../../services/uwb/uwb_anchor.dart';
import '../../../services/uwb/uwb_position.dart';
import '../../../services/uwb/uwb_service.dart';

// ── Canvas transform (tap → world coords) ─────────────────────────────────────

class _CanvasTransform {
  double offsetX = 0, offsetY = 0, scale = 1, minX = 0, maxY = 0;

  Offset toWorld(Offset canvas) => Offset(
        minX + (canvas.dx - offsetX) / scale,
        maxY - (canvas.dy - offsetY) / scale,
      );
}

// ── Navigation path ───────────────────────────────────────────────────────────

class _NavPath {
  final List<Offset> waypoints;
  final List<bool> isCorner;
  int currentIndex;

  _NavPath({required this.waypoints, this.isCorner = const []})
      : currentIndex = 1;

  Offset get current => waypoints[currentIndex];
  Offset get destination => waypoints.last;
  bool get isLast => currentIndex == waypoints.length - 1;
  int get totalSteps => waypoints.length - 1;
  int get step => currentIndex;

  bool get isCurrentCorner {
    if (isCorner.isEmpty) return false;
    return currentIndex < isCorner.length && isCorner[currentIndex];
  }

  void advance() {
    if (!isLast) currentIndex++;
  }

  /// Build a clean L-shaped path: start → corner → destination
  static _NavPath build(Offset from, Offset to) {
    final router = CorridorRouter();
    final pathCorners = router.findPath(from, to);

    final waypoints = pathCorners.map((pc) => pc.position).toList();
    final isCorner = pathCorners.map((pc) => pc.isCorner).toList();

    return _NavPath(waypoints: waypoints, isCorner: isCorner);
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class UwbMapPage extends StatefulWidget {
  const UwbMapPage({Key? key}) : super(key: key);

  @override
  State<UwbMapPage> createState() => _UwbMapPageState();
}

class _UwbMapPageState extends State<UwbMapPage> {
  late final UwbService _uwbService;
  late final WearableHapticService _wearableService;
  UwbPosition? _position;
  UwbPosition? _prevPosition;
  UwbConnectionState _connState = UwbConnectionState.disconnected;
  double? _compassDeg;
  double? _movementDeg;
  double? _smoothedMovementDeg;
  _NavPath? _path;
  _NavInstruction? _lastInstruction;
  StreamSubscription? _posSub;
  StreamSubscription? _connSub;
  StreamSubscription<CompassEvent>? _compassSub;

  final _transform = _CanvasTransform();

  static const double _minMoveDist = 0.15;
  static const double _emaAlpha = 0.4;
  static const double _waypointRadius = 0.6;
  static const Duration _hapticInterval = Duration(seconds: 1);

  Timer? _hapticTimer;

  @override
  void initState() {
    super.initState();
    _uwbService = GetIt.I<UwbService>();
    _wearableService = GetIt.I<WearableHapticService>();
    _connState = _uwbService.isConnected
        ? UwbConnectionState.connected
        : UwbConnectionState.disconnected;
    _position = _uwbService.lastPosition;

    _wearableService.connect().catchError((_) {});

    _hapticTimer =
        Timer.periodic(_hapticInterval, (_) => _sendPeriodicHaptic());

    _posSub = _uwbService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        // Movement vector
        if (_prevPosition != null) {
          final dx = pos.x - _prevPosition!.x;
          final dy = pos.y - _prevPosition!.y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist >= _minMoveDist) {
            final rawDeg = atan2(dx, dy) * 180 / pi;
            final normalized = (rawDeg + 360) % 360;
            if (_smoothedMovementDeg == null) {
              _smoothedMovementDeg = normalized;
            } else {
              double diff = normalized - _smoothedMovementDeg!;
              if (diff > 180) diff -= 360;
              if (diff < -180) diff += 360;
              _smoothedMovementDeg =
                  (_smoothedMovementDeg! + _emaAlpha * diff + 360) % 360;
            }
            _movementDeg = _smoothedMovementDeg;
          }
        }
        _prevPosition = _position;
        _position = pos;

        // Advance path waypoint if close enough - recalculate route in real-time
        if (_path != null) {
          final wp = _path!.current;
          final dx = wp.dx - pos.x;
          final dy = wp.dy - pos.y;
          final d = sqrt(dx * dx + dy * dy);

          if (d < _waypointRadius) {
            _path!.advance();

            // Recalculate route from new position to destination
            if (!_path!.isLast && _position != null) {
              final newPath = _NavPath.build(
                Offset(pos.x, pos.y),
                _path!.destination,
              );
              setState(() => _path = newPath);
            }
          }
        }
      });
    });

    _connSub = _uwbService.connectionStateStream.stream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _compassDeg = event.heading);
      }
    });
  }

  double? get _activeHeading => _movementDeg ?? _compassDeg;

  bool get _arrived {
    if (_path == null || _position == null) return false;
    final dest = _path!.destination;
    final dx = dest.dx - _position!.x;
    final dy = dest.dy - _position!.y;
    return sqrt(dx * dx + dy * dy) < _waypointRadius && _path!.isLast;
  }

  // Bearing from current position to current waypoint
  double? get _bearingToWaypoint {
    if (_path == null || _position == null) return null;
    final wp = _path!.current;
    final dx = wp.dx - _position!.x;
    final dy = wp.dy - _position!.y;
    return (atan2(dx, dy) * 180 / pi + 360) % 360;
  }

  _NavInstruction? get _instruction {
    if (_arrived || _path == null) return null;
    final bearing = _bearingToWaypoint;
    final heading = _activeHeading;
    if (bearing == null || heading == null) return null;
    double diff = (bearing - heading + 360) % 360;
    if (diff > 180) diff -= 360;
    _NavInstruction inst;
    if (diff.abs() < 30) {
      inst = _NavInstruction.forward;
    } else if (diff > 30 && diff <= 150) {
      inst = _NavInstruction.right;
    } else if (diff < -30 && diff >= -150) {
      inst = _NavInstruction.left;
    } else {
      inst = _NavInstruction.turnAround;
    }
    if (inst != _lastInstruction && _path != null) {
      _lastInstruction = inst;
      final isCorner = _path!.isCurrentCorner;
      final isDest = _path!.isLast;
      if (isCorner || isDest) {
        _triggerHaptic(inst);
      }
    }
    return inst;
  }

  void _triggerHaptic(_NavInstruction inst) {
    if (!_wearableService.isConnected) return;
    if (_path != null && _path!.isLast) {
      _wearableService.triggerDirection(TurnDirection.arrived);
      return;
    }
    TurnDirection? dir;
    switch (inst) {
      case _NavInstruction.forward:
        return;
      case _NavInstruction.left:
        dir = TurnDirection.left;
      case _NavInstruction.right:
        dir = TurnDirection.right;
      case _NavInstruction.turnAround:
        dir = TurnDirection.left;
    }
    if (dir != null) _wearableService.triggerDirection(dir);
  }

  void _sendPeriodicHaptic() {
    if (_path == null || _position == null) return;
    if (!_wearableService.isConnected) return;
    if (_arrived) return;

    final bearing = _bearingToWaypoint;
    final heading = _activeHeading;
    if (bearing == null || heading == null) return;

    double diff = (bearing - heading + 360) % 360;
    if (diff > 180) diff -= 360;

    TurnDirection? dir;
    if (diff.abs() < 30) {
      dir = TurnDirection.straight;
    } else if (diff > 30 && diff <= 150) {
      dir = TurnDirection.right;
    } else if (diff < -30 && diff >= -150) {
      dir = TurnDirection.left;
    } else {
      dir = TurnDirection.left;
    }

    _wearableService.triggerDirection(dir);
  }

  double? get _distToCurrentWaypoint {
    if (_path == null || _position == null) return null;
    final wp = _path!.current;
    final dx = wp.dx - _position!.x;
    final dy = wp.dy - _position!.y;
    return sqrt(dx * dx + dy * dy);
  }

  void _onTap(TapUpDetails details) {
    if (_position == null) return;
    final world = _transform.toWorld(details.localPosition);
    setState(() {
      _path = _NavPath.build(
        Offset(_position!.x, _position!.y),
        world,
      );
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _connSub?.cancel();
    _compassSub?.cancel();
    _hapticTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('UWB Live Map'),
        actions: [
          if (_path != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Clear route',
              onPressed: () => setState(() => _path = null),
            ),
          if (_activeHeading != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _HeadingBadge(heading: _activeHeading!),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _ConnBadge(state: _connState),
          ),
        ],
      ),
      body: Column(
        children: [
          // Navigation card
          if (_path != null)
            _NavCard(
              instruction: _arrived ? null : _instruction,
              distToWaypoint: _distToCurrentWaypoint,
              step: _path!.step,
              totalSteps: _path!.totalSteps,
              arrived: _arrived,
            ),

          // Map
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: GestureDetector(
                onTapUp: _onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: _MapPainter(
                        anchors: _uwbService.anchors,
                        tagPosition: _position,
                        headingDeg: _activeHeading,
                        path: _path,
                        transform: _transform,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (_path == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'Tap on the map to set a destination',
                style: TextStyle(color: AppTheme.darkOnMuted, fontSize: 12),
              ),
            ),

          _InfoPanel(
            position: _position,
            anchors: _uwbService.anchors,
            headingDeg: _activeHeading,
          ),
        ],
      ),
    );
  }
}

enum _NavInstruction { forward, left, right, turnAround }

// ── Navigation Card ───────────────────────────────────────────────────────────

class _NavCard extends StatelessWidget {
  final _NavInstruction? instruction;
  final double? distToWaypoint;
  final int step;
  final int totalSteps;
  final bool arrived;

  const _NavCard({
    required this.instruction,
    required this.distToWaypoint,
    required this.step,
    required this.totalSteps,
    required this.arrived,
  });

  @override
  Widget build(BuildContext context) {
    if (arrived) {
      return _card(
          AppTheme.successColor, Icons.check_circle, 'You have arrived!', null);
    }
    if (instruction == null) {
      return _card(
          Colors.grey, Icons.directions_walk, 'Start moving…', distToWaypoint);
    }
    switch (instruction!) {
      case _NavInstruction.forward:
        return _card(AppTheme.successColor, Icons.arrow_upward, 'Go Forward',
            distToWaypoint);
      case _NavInstruction.left:
        return _card(
            Colors.orange, Icons.turn_left, 'Turn Left', distToWaypoint);
      case _NavInstruction.right:
        return _card(
            Colors.orange, Icons.turn_right, 'Turn Right', distToWaypoint);
      case _NavInstruction.turnAround:
        return _card(
            Colors.red, Icons.u_turn_left, 'Turn Around', distToWaypoint);
    }
  }

  Widget _card(Color color, IconData icon, String label, double? dist) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                Text('Step $step of $totalSteps',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.7), fontSize: 11)),
              ],
            ),
          ),
          if (dist != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dist < 1
                      ? '${(dist * 100).toStringAsFixed(0)} cm'
                      : '${dist.toStringAsFixed(1)} m',
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('to checkpoint',
                    style: TextStyle(
                        color: color.withValues(alpha: 0.7), fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Map Painter ───────────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbPosition? tagPosition;
  final double? headingDeg;
  final _NavPath? path;
  final _CanvasTransform transform;

  _MapPainter({
    required this.anchors,
    required this.tagPosition,
    required this.headingDeg,
    required this.path,
    required this.transform,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) return;

    const padding = 48.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    final xs = anchors.map((a) => a.x).toList();
    final ys = anchors.map((a) => a.y).toList();
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);

    final spaceW = (maxX - minX).clamp(1.0, double.infinity);
    final spaceH = (maxY - minY).clamp(1.0, double.infinity);
    final scaleX = drawW / spaceW;
    final scaleY = drawH / spaceH;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final offsetX = padding + (drawW - spaceW * scale) / 2;
    final offsetY = padding + (drawH - spaceH * scale) / 2;

    transform
      ..offsetX = offsetX
      ..offsetY = offsetY
      ..scale = scale
      ..minX = minX
      ..maxY = maxY;

    Offset tc(double x, double y) => Offset(
          offsetX + (x - minX) * scale,
          offsetY + (maxY - y) * scale,
        );

    // Grid
    final gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var gx = 0.0; gx <= spaceW; gx += 1.0) {
      canvas.drawLine(tc(minX + gx, minY), tc(minX + gx, maxY), gridPaint);
    }
    for (var gy = 0.0; gy <= spaceH; gy += 1.0) {
      canvas.drawLine(tc(minX, minY + gy), tc(maxX, minY + gy), gridPaint);
    }

    _drawNorthIndicator(canvas);

    // Anchor rings
    for (final a in anchors) {
      if (a.distanceMeters > 0) {
        canvas.drawCircle(
            tc(a.x, a.y),
            a.distanceMeters * scale,
            Paint()
              ..color = AppTheme.primaryColor.withValues(alpha: 0.18)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
      }
    }

    // Route: clean L-shape - straight lines from start to corner to destination
    if (path != null) {
      final pts = path!.waypoints;

      // Draw two straight lines: start→corner→dest (L-shape)
      for (int i = 0; i < pts.length - 1; i++) {
        final a = tc(pts[i].dx, pts[i].dy);
        final b = tc(pts[i + 1].dx, pts[i + 1].dy);
        final isCorner = path!.isCorner.length > i + 1 && path!.isCorner[i + 1];
        final done = i < path!.currentIndex - 1;

        Paint linePaint = Paint()
          ..color = done
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.yellow.withValues(alpha: 0.7)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;

        if (isCorner && !done) {
          linePaint.color = Colors.orange;
        }

        canvas.drawLine(a, b, linePaint);

        if (isCorner && !done) {
          canvas.drawCircle(
              a,
              10,
              Paint()
                ..color = Colors.orange
                ..style = PaintingStyle.fill);
          _drawLabel(canvas, 'TURN', Colors.orange, 10, a, -18, bold: true);
        }
      }

      // Destination marker
      final dest = tc(pts.last.dx, pts.last.dy);
      canvas.drawCircle(
          dest, 14, Paint()..color = Colors.yellow.withValues(alpha: 0.2));
      canvas.drawCircle(
          dest,
          14,
          Paint()
            ..color = Colors.yellow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      const r = 6.0;
      final xp = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2;
      canvas.drawLine(
          dest + const Offset(-r, -r), dest + const Offset(r, r), xp);
      canvas.drawLine(
          dest + const Offset(r, -r), dest + const Offset(-r, r), xp);
      _drawLabel(canvas, 'DEST', Colors.yellow, 11, dest, 20, bold: true);
    }

    // Anchors
    for (final a in anchors) {
      final pos = tc(a.x, a.y);
      canvas.drawCircle(pos, 10,
          Paint()..color = AppTheme.primaryColor.withValues(alpha: 0.9));
      canvas.drawCircle(
          pos,
          10,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _drawLabel(canvas, a.name, Colors.white, 11, pos, 13);
      _drawLabel(
          canvas,
          '(${a.x.toStringAsFixed(0)}, ${a.y.toStringAsFixed(0)})',
          AppTheme.darkOnMuted,
          9,
          pos,
          25);
    }

    // Tag
    if (tagPosition != null) {
      final tagPos = tc(tagPosition!.x, tagPosition!.y);
      if (headingDeg != null) _drawArrow(canvas, tagPos, headingDeg!);
      canvas.drawCircle(
          tagPos,
          14,
          Paint()
            ..color = AppTheme.successColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(tagPos, 10, Paint()..color = AppTheme.successColor);
      canvas.drawCircle(
          tagPos,
          10,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _drawLabel(canvas, 'YOU', Colors.white, 11, tagPos, 13, bold: true);
      _drawLabel(
          canvas,
          '(${tagPosition!.x.toStringAsFixed(2)}, ${tagPosition!.y.toStringAsFixed(2)})',
          AppTheme.successColor,
          9,
          tagPos,
          25);
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 8.0, gap = 5.0;
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = sqrt(dx * dx + dy * dy);
    final ux = dx / len, uy = dy / len;
    double t = 0;
    bool draw = true;
    while (t < len) {
      final seg = draw ? dash : gap;
      final t2 = min(t + seg, len);
      if (draw) {
        canvas.drawLine(
          a + Offset(ux * t, uy * t),
          a + Offset(ux * t2, uy * t2),
          paint,
        );
      }
      t = t2;
      draw = !draw;
    }
  }

  void _drawArrow(Canvas canvas, Offset origin, double deg) {
    const len = 40.0, head = 10.0;
    final rad = deg * pi / 180;
    final dx = sin(rad), dy = -cos(rad);
    final tip = origin + Offset(dx * len, dy * len);
    final p = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(origin, tip, p);
    final back = atan2(dy, dx);
    canvas.drawLine(
        tip, tip + Offset(cos(back + 2.5) * head, sin(back + 2.5) * head), p);
    canvas.drawLine(
        tip, tip + Offset(cos(back - 2.5) * head, sin(back - 2.5) * head), p);
  }

  void _drawNorthIndicator(Canvas canvas) {
    const x = 30.0, y = 30.0, len = 16.0;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(x, y + len), const Offset(x, y - len), p);
    canvas.drawLine(
        const Offset(x, y - len), const Offset(x - 5, y - len + 7), p);
    canvas.drawLine(
        const Offset(x, y - len), const Offset(x + 5, y - len + 7), p);
    _drawLabel(canvas, 'N', Colors.white.withValues(alpha: 0.6), 10,
        const Offset(x, y - len - 4), -12);
  }

  void _drawLabel(Canvas canvas, String text, Color color, double size,
      Offset center, double yOff,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, yOff));
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.tagPosition != tagPosition ||
      old.anchors != anchors ||
      old.headingDeg != headingDeg ||
      old.path?.currentIndex != path?.currentIndex ||
      old.path?.waypoints != path?.waypoints;
}

// ── Info Panel ────────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final UwbPosition? position;
  final List<UwbAnchor> anchors;
  final double? headingDeg;

  const _InfoPanel({
    required this.position,
    required this.anchors,
    required this.headingDeg,
  });

  String _cardinal(double deg) {
    if (deg < 22.5 || deg >= 337.5) return 'N';
    if (deg < 67.5) return 'NE';
    if (deg < 112.5) return 'E';
    if (deg < 157.5) return 'SE';
    if (deg < 202.5) return 'S';
    if (deg < 247.5) return 'SW';
    if (deg < 292.5) return 'W';
    return 'NW';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 14, color: AppTheme.successColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  position != null
                      ? 'x = ${position!.x.toStringAsFixed(2)} m    y = ${position!.y.toStringAsFixed(2)} m'
                      : 'Tag: waiting for data...',
                  style: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ),
              if (headingDeg != null) ...[
                const Icon(Icons.navigation, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '${headingDeg!.toStringAsFixed(0)}°  ${_cardinal(headingDeg!)}',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: anchors.map((a) {
              final dist = a.distanceMeters > 0
                  ? '${a.distanceMeters.toStringAsFixed(2)} m'
                  : '—';
              return Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.cell_tower,
                        size: 14, color: AppTheme.primaryColor),
                    const SizedBox(height: 2),
                    Text(a.name,
                        style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    Text(dist,
                        style: const TextStyle(
                            color: AppTheme.darkOnMuted, fontSize: 11)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Heading Badge ─────────────────────────────────────────────────────────────

class _HeadingBadge extends StatelessWidget {
  final double heading;
  const _HeadingBadge({required this.heading});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: heading * pi / 180,
        child: const Icon(Icons.navigation, color: Colors.orange, size: 20),
      );
}

// ── Connection Badge ──────────────────────────────────────────────────────────

class _ConnBadge extends StatelessWidget {
  final UwbConnectionState state;
  const _ConnBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state == UwbConnectionState.connected
        ? AppTheme.successColor
        : state == UwbConnectionState.connecting
            ? AppTheme.warningColor
            : Colors.red;
    final label = state == UwbConnectionState.connected
        ? 'Connected'
        : state == UwbConnectionState.connecting
            ? 'Searching...'
            : 'Disconnected';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.radar, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
