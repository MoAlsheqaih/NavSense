import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/uwb/ble_uwb_service.dart';
import '../../../services/uwb/uwb_anchor.dart';
import '../../../services/uwb/uwb_position.dart';
import '../../../services/uwb/uwb_service.dart';

class UwbMapPage extends StatefulWidget {
  const UwbMapPage({Key? key}) : super(key: key);

  @override
  State<UwbMapPage> createState() => _UwbMapPageState();
}

class _UwbMapPageState extends State<UwbMapPage> {
  late final UwbService _uwbService;
  UwbPosition? _position;
  UwbPosition? _prevPosition;
  UwbConnectionState _connState = UwbConnectionState.disconnected;
  double? _compassDeg;    // raw compass heading
  double? _movementDeg;   // direction from UWB movement vector (primary)
  double? _smoothedMovementDeg; // EMA-smoothed movement direction
  String? _rawData;
  StreamSubscription? _posSub;
  StreamSubscription? _connSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _rawTimer;

  static const double _minMoveDist = 0.15; // metres — ignore jitter below this
  static const double _emaAlpha = 0.4;

  @override
  void initState() {
    super.initState();
    _uwbService = GetIt.I<UwbService>();
    _connState = _uwbService.isConnected
        ? UwbConnectionState.connected
        : UwbConnectionState.disconnected;
    _position = _uwbService.lastPosition;

    _posSub = _uwbService.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() {
        // Compute movement vector from previous position
        if (_prevPosition != null) {
          final dx = pos.x - _prevPosition!.x;
          final dy = pos.y - _prevPosition!.y;
          final dist = sqrt(dx * dx + dy * dy);
          if (dist >= _minMoveDist) {
            // atan2(dx,dy): dy=North(+Y), dx=East(+X) → degrees clockwise from North
            final rawDeg = atan2(dx, dy) * 180 / pi;
            final normalized = (rawDeg + 360) % 360;
            if (_smoothedMovementDeg == null) {
              _smoothedMovementDeg = normalized;
            } else {
              // EMA on angle (handle wraparound)
              double diff = normalized - _smoothedMovementDeg!;
              if (diff > 180) diff -= 360;
              if (diff < -180) diff += 360;
              _smoothedMovementDeg = (_smoothedMovementDeg! + _emaAlpha * diff + 360) % 360;
            }
            _movementDeg = _smoothedMovementDeg;
          }
        }
        _prevPosition = _position;
        _position = pos;
      });
    });

    _connSub = _uwbService.connectionStateStream.stream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });

    // Compass as fallback
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted && event.heading != null) {
        setState(() => _compassDeg = event.heading);
      }
    });

    _rawTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final raw = (_uwbService is BleUwbService)
          ? (_uwbService as BleUwbService).lastRawData
          : null;
      if (raw != _rawData) setState(() => _rawData = raw);
    });
  }

  // Active heading: prefer movement vector, fall back to compass
  double? get _activeHeading => _movementDeg ?? _compassDeg;

  @override
  void dispose() {
    _rawTimer?.cancel();
    _posSub?.cancel();
    _connSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('UWB Live Map'),
        actions: [
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _UwbMapCanvas(
                anchors: _uwbService.anchors,
                tagPosition: _position,
                headingDeg: _activeHeading,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _activeHeading != null
                      ? Colors.orange.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Text(
              _movementDeg != null
                  ? 'Direction (movement): ${_movementDeg!.toStringAsFixed(1)}°'
                  : _compassDeg != null
                      ? 'Direction (compass): ${_compassDeg!.toStringAsFixed(1)}°'
                      : 'Direction: move to detect...',
              style: TextStyle(
                  color: _activeHeading != null ? Colors.orange : Colors.grey,
                  fontSize: 11,
                  fontFamily: 'monospace'),
            ),
          ),
          if (_rawData != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
              ),
              child: Text(
                'RAW: $_rawData',
                style: const TextStyle(
                    color: Colors.green, fontSize: 10, fontFamily: 'monospace'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
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

// ── Map Canvas ────────────────────────────────────────────────────────────────

class _UwbMapCanvas extends StatelessWidget {
  final List<UwbAnchor> anchors;
  final UwbPosition? tagPosition;
  final double? headingDeg;

  const _UwbMapCanvas({
    required this.anchors,
    required this.tagPosition,
    required this.headingDeg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _MapPainter(
            anchors: anchors,
            tagPosition: tagPosition,
            headingDeg: headingDeg,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbPosition? tagPosition;
  final double? headingDeg;

  _MapPainter({
    required this.anchors,
    required this.tagPosition,
    required this.headingDeg,
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

    Offset toCanvas(double x, double y) => Offset(
          offsetX + (x - minX) * scale,
          offsetY + (maxY - y) * scale,
        );

    // Grid
    final gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var gx = 0.0; gx <= spaceW; gx += 1.0) {
      canvas.drawLine(
          toCanvas(minX + gx, minY), toCanvas(minX + gx, maxY), gridPaint);
    }
    for (var gy = 0.0; gy <= spaceH; gy += 1.0) {
      canvas.drawLine(
          toCanvas(minX, minY + gy), toCanvas(maxX, minY + gy), gridPaint);
    }

    // North indicator (top-right corner)
    _drawNorthIndicator(canvas, size);

    // Anchor distance rings
    for (final anchor in anchors) {
      if (anchor.distanceMeters > 0) {
        canvas.drawCircle(
          toCanvas(anchor.x, anchor.y),
          anchor.distanceMeters * scale,
          Paint()
            ..color = AppTheme.primaryColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }

    // Anchor markers
    for (final anchor in anchors) {
      final pos = toCanvas(anchor.x, anchor.y);
      canvas.drawCircle(
          pos, 10, Paint()..color = AppTheme.primaryColor.withValues(alpha: 0.9));
      canvas.drawCircle(
          pos,
          10,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _drawLabel(canvas, anchor.name, Colors.white, 11, pos, 13);
      _drawLabel(
        canvas,
        '(${anchor.x.toStringAsFixed(0)}, ${anchor.y.toStringAsFixed(0)})',
        AppTheme.darkOnMuted,
        9,
        pos,
        25,
      );
    }

    // Tag marker + direction arrow
    if (tagPosition != null) {
      final tagPos = toCanvas(tagPosition!.x, tagPosition!.y);

      // Draw direction arrow if heading is available
      if (headingDeg != null) {
        _drawDirectionArrow(canvas, tagPos, headingDeg!);
      }

      // Glow ring
      canvas.drawCircle(
          tagPos,
          14,
          Paint()
            ..color = AppTheme.successColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Solid dot
      canvas.drawCircle(tagPos, 10, Paint()..color = AppTheme.successColor);
      canvas.drawCircle(
          tagPos,
          10,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      _drawLabel(canvas, 'TAG', Colors.white, 11, tagPos, 13, bold: true);
      _drawLabel(
        canvas,
        '(${tagPosition!.x.toStringAsFixed(2)}, ${tagPosition!.y.toStringAsFixed(2)})',
        AppTheme.successColor,
        9,
        tagPos,
        25,
      );
    }
  }

  /// Draws a direction arrow from [origin] pointing in [headingDeg] degrees.
  /// 0° = North (+Y world = up on canvas), 90° = East (+X).
  void _drawDirectionArrow(Canvas canvas, Offset origin, double headingDeg) {
    const arrowLength = 40.0;
    const arrowHeadSize = 10.0;

    final rad = headingDeg * pi / 180.0;
    // Canvas Y is flipped: North (0°) points up (-Y), East (90°) points right (+X)
    final dx = sin(rad);
    final dy = -cos(rad);

    final tip = origin + Offset(dx * arrowLength, dy * arrowLength);

    final arrowPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Shaft
    canvas.drawLine(origin, tip, arrowPaint);

    // Arrowhead — two lines fanning back from the tip
    final backAngle = atan2(dy, dx);
    final left = tip +
        Offset(cos(backAngle + 2.5) * arrowHeadSize,
            sin(backAngle + 2.5) * arrowHeadSize);
    final right = tip +
        Offset(cos(backAngle - 2.5) * arrowHeadSize,
            sin(backAngle - 2.5) * arrowHeadSize);

    canvas.drawLine(tip, left, arrowPaint);
    canvas.drawLine(tip, right, arrowPaint);
  }

  void _drawNorthIndicator(Canvas canvas, Size size) {
    const x = 30.0;
    const y = 30.0;
    const len = 16.0;

    canvas.drawLine(
      const Offset(x, y + len),
      const Offset(x, y - len),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
    // Arrowhead
    canvas.drawLine(const Offset(x, y - len),
        const Offset(x - 5, y - len + 7),
        Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.5);
    canvas.drawLine(const Offset(x, y - len),
        const Offset(x + 5, y - len + 7),
        Paint()..color = Colors.white.withValues(alpha: 0.5)..strokeWidth = 1.5);

    _drawLabel(canvas, 'N', Colors.white.withValues(alpha: 0.6), 10,
        const Offset(x, y - len - 4), -12);
  }

  void _drawLabel(Canvas canvas, String text, Color color, double fontSize,
      Offset center, double yOffset,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-tp.width / 2, yOffset));
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.tagPosition != tagPosition ||
      old.anchors != anchors ||
      old.headingDeg != headingDeg;
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

  String _headingLabel(double deg) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 14, color: AppTheme.successColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  position != null
                      ? 'x = ${position!.x.toStringAsFixed(2)} m    '
                          'y = ${position!.y.toStringAsFixed(2)} m'
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
                  '${headingDeg!.toStringAsFixed(0)}°  ${_headingLabel(headingDeg!)}',
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

// ── Heading Badge (AppBar) ────────────────────────────────────────────────────

class _HeadingBadge extends StatelessWidget {
  final double heading;
  const _HeadingBadge({required this.heading});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: heading * pi / 180,
      child: const Icon(Icons.navigation, color: Colors.orange, size: 20),
    );
  }
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
