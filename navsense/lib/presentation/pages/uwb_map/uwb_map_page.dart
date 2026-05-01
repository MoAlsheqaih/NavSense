import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:get_it/get_it.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/route_plan.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic/haptic_service.dart';
import '../../../services/haptic/wearable_haptic_service.dart';
import '../../../services/logging/uwb_accuracy_logger.dart';
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

// ── Page ──────────────────────────────────────────────────────────────────────

class UwbMapPage extends StatefulWidget {
  const UwbMapPage({Key? key}) : super(key: key);

  @override
  State<UwbMapPage> createState() => _UwbMapPageState();
}

class _UwbMapPageState extends State<UwbMapPage> {
  late final UwbService _uwbService;
  late final WearableHapticService _wearableService;
  late final HapticService _hapticService;
  UwbPosition? _position;
  UwbPosition? _prevPosition;
  UwbConnectionState _connState = UwbConnectionState.disconnected;
  double? _compassDeg;
  double? _movementDeg;
  double? _smoothedMovementDeg;
  Offset? _destination;
  _NavInstruction? _lastFiredInstruction;
  DateTime? _lastHapticTime;
  bool _navigationComplete = false;
  StreamSubscription? _posSub;
  StreamSubscription? _connSub;
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _renderTimer;
  bool _dirty = false;

  final _transform = _CanvasTransform();

  static const double _minMoveDist = 0.15;
  static const double _emaAlpha = 0.4;
  static const double _arrivalRadius = 1.0;
  static const Duration _hapticCooldown = Duration(seconds: 2);
  static const Duration _hapticReminder = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _uwbService = GetIt.I<UwbService>();
    _wearableService = GetIt.I<WearableHapticService>();
    _hapticService = GetIt.I<HapticService>();
    _connState = _uwbService.isConnected
        ? UwbConnectionState.connected
        : UwbConnectionState.disconnected;
    _position = _uwbService.lastPosition;

    _wearableService.connect().catchError((_) {});

    _renderTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_dirty && mounted) {
        _dirty = false;
        setState(() {});
      }
    });

    _posSub = _uwbService.positionStream.listen((pos) {
      if (!mounted) return;

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
      _dirty = true;

      if (_navigationComplete) return;

      if (_arrived) {
        _navigationComplete = true;
        _fireArrivalHaptic();
      } else {
        final inst = _instruction;
        if (inst != null) _checkAndFireHaptic(inst);
      }
    });

    _connSub = _uwbService.connectionStateStream.stream.listen((s) {
      _connState = s;
      if (mounted) setState(() {});
    });

    _compassSub = FlutterCompass.events?.listen((event) {
      if (event.heading == null) return;
      _compassDeg = event.heading;
      _dirty = true;
    });
  }

  double? get _activeHeading => _movementDeg ?? _compassDeg;

  bool get _arrived {
    if (_destination == null || _position == null) return false;
    final dx = _destination!.dx - _position!.x;
    final dy = _destination!.dy - _position!.y;
    return sqrt(dx * dx + dy * dy) < _arrivalRadius;
  }

  double? get _bearingToDestination {
    if (_destination == null || _position == null) return null;
    final dx = _destination!.dx - _position!.x;
    final dy = _destination!.dy - _position!.y;
    return (atan2(dx, dy) * 180 / pi + 360) % 360;
  }

  double? get _distToDestination {
    if (_destination == null || _position == null) return null;
    final dx = _destination!.dx - _position!.x;
    final dy = _destination!.dy - _position!.y;
    return sqrt(dx * dx + dy * dy);
  }

  _NavInstruction? get _instruction {
    if (_arrived || _destination == null) return null;
    final bearing = _bearingToDestination;
    final heading = _activeHeading;
    if (bearing == null || heading == null) return null;
    double diff = (bearing - heading + 360) % 360;
    if (diff > 180) diff -= 360;
    if (diff.abs() < 30) return _NavInstruction.forward;
    if (diff > 30 && diff <= 150) return _NavInstruction.right;
    if (diff < -30 && diff >= -150) return _NavInstruction.left;
    return _NavInstruction.turnAround;
  }

  void _checkAndFireHaptic(_NavInstruction inst) {
    final now = DateTime.now();
    final elapsed =
        _lastHapticTime == null ? null : now.difference(_lastHapticTime!);
    final changed = inst != _lastFiredInstruction;

    if (changed) {
      if (elapsed == null || elapsed >= _hapticCooldown) {
        _fireDirectionHaptic(inst);
        _lastFiredInstruction = inst;
        _lastHapticTime = now;
      }
    } else if (inst != _NavInstruction.forward) {
      if (elapsed != null && elapsed >= _hapticReminder) {
        _fireDirectionHaptic(inst);
        _lastHapticTime = now;
      }
    }
  }

  void _fireDirectionHaptic(_NavInstruction inst) {
    switch (inst) {
      case _NavInstruction.forward:
        _hapticService.triggerStraight();
        if (_wearableService.isConnected) {
          _wearableService.triggerDirection(TurnDirection.straight);
        }
      case _NavInstruction.left:
        _hapticService.triggerLeft();
        if (_wearableService.isConnected) {
          _wearableService.triggerDirection(TurnDirection.left);
        }
      case _NavInstruction.right:
        _hapticService.triggerRight();
        if (_wearableService.isConnected) {
          _wearableService.triggerDirection(TurnDirection.right);
        }
      case _NavInstruction.turnAround:
        _hapticService.triggerTurnAround();
        if (_wearableService.isConnected) {
          _wearableService.triggerDirection(TurnDirection.turnAround);
        }
    }
  }

  void _fireArrivalHaptic() {
    _hapticService.triggerArrival();
    _wearableService.triggerDirection(TurnDirection.arrived).catchError((_) {});
  }

  Future<void> _exportAccuracyLog() async {
    final l10n = AppLocalizations.of(context)!;
    final path = await UwbAccuracyLogger.instance.filePath;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.uwbNoAccuracyData)),
        );
      }
      return;
    }
    final params = ShareParams(files: [XFile(path)], subject: 'UWB Accuracy Log');
    await SharePlus.instance.share(params);
  }

  void _onTap(TapUpDetails details) {
    final world = _transform.toWorld(details.localPosition);
    setState(() {
      _destination = world;
      _lastFiredInstruction = null;
      _lastHapticTime = null;
      _navigationComplete = false;
    });
  }

  @override
  void dispose() {
    _renderTimer?.cancel();
    _posSub?.cancel();
    _connSub?.cancel();
    _compassSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: Text(l10n.uwbMapTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, size: 20),
            tooltip: l10n.uwbExportLog,
            onPressed: _exportAccuracyLog,
          ),
          if (_destination != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: l10n.uwbClearRoute,
              onPressed: () => setState(() => _destination = null),
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
          if (_destination != null)
            _NavCard(
              instruction: _arrived ? null : _instruction,
              distToDestination: _distToDestination,
              arrived: _arrived,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
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
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _MapPainter(
                              anchors: _uwbService.anchors,
                              tagPosition: _position,
                              headingDeg: _activeHeading,
                              destination: _destination,
                              transform: _transform,
                              arrivalRadius: _arrivalRadius,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _InfoBar(
                            position: _position,
                            anchors: _uwbService.anchors,
                            headingDeg: _activeHeading,
                            noRoute: _destination == null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
  final double? distToDestination;
  final bool arrived;

  const _NavCard({
    required this.instruction,
    required this.distToDestination,
    required this.arrived,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (arrived) {
      return _card(context, AppTheme.successColor, Icons.check_circle,
          l10n.instruction_arrived);
    }
    if (instruction == null) {
      return _card(
          context, Colors.grey, Icons.directions_walk, l10n.uwbStartMoving);
    }
    switch (instruction!) {
      case _NavInstruction.forward:
        return _card(context, AppTheme.successColor, Icons.arrow_upward,
            l10n.uwbGoForward);
      case _NavInstruction.left:
        return _card(
            context, Colors.orange, Icons.turn_left, l10n.instruction_turn_left);
      case _NavInstruction.right:
        return _card(context, Colors.orange, Icons.turn_right,
            l10n.instruction_turn_right);
      case _NavInstruction.turnAround:
        return _card(context, Colors.red, Icons.u_turn_left,
            l10n.instructionTurnAround);
    }
  }

  Widget _card(BuildContext context, Color color, IconData icon, String label) {
    final l10n = AppLocalizations.of(context)!;
    final dist = distToDestination;
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
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 20, fontWeight: FontWeight.bold)),
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
                Text(l10n.uwbToDestination,
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
  final Offset? destination;
  final _CanvasTransform transform;
  final double arrivalRadius;

  _MapPainter({
    required this.anchors,
    required this.tagPosition,
    required this.headingDeg,
    required this.destination,
    required this.transform,
    this.arrivalRadius = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) return;

    const padding = 12.0;
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

    if (destination != null && tagPosition != null) {
      final from = tc(tagPosition!.x, tagPosition!.y);
      final dest = tc(destination!.dx, destination!.dy);

      canvas.drawLine(
          from,
          dest,
          Paint()
            ..color = Colors.yellow.withValues(alpha: 0.7)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);

      final zoneR = arrivalRadius * transform.scale;
      canvas.drawCircle(
          dest, zoneR, Paint()..color = Colors.yellow.withValues(alpha: 0.08));
      canvas.drawCircle(
          dest,
          zoneR,
          Paint()
            ..color = Colors.yellow.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      const r = 6.0;
      final xp = Paint()
        ..color = Colors.yellow
        ..strokeWidth = 2;
      canvas.drawLine(dest + const Offset(-r, -r), dest + const Offset(r, r), xp);
      canvas.drawLine(dest + const Offset(r, -r), dest + const Offset(-r, r), xp);
      _drawLabel(canvas, 'DEST', Colors.yellow, 11, dest, zoneR + 4, bold: true);
    } else if (destination != null) {
      final dest = tc(destination!.dx, destination!.dy);
      final zoneR = arrivalRadius * transform.scale;
      canvas.drawCircle(
          dest, zoneR, Paint()..color = Colors.yellow.withValues(alpha: 0.08));
      canvas.drawCircle(
          dest,
          zoneR,
          Paint()
            ..color = Colors.yellow.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
      _drawLabel(canvas, 'DEST', Colors.yellow, 11, dest, zoneR + 4, bold: true);
    }

    for (final a in anchors) {
      final pos = tc(a.x, a.y);
      canvas.drawCircle(
          pos, 10, Paint()..color = AppTheme.primaryColor.withValues(alpha: 0.9));
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
  bool shouldRepaint(_MapPainter old) {
    if (old.destination != destination) return true;
    if (old.tagPosition?.x != tagPosition?.x ||
        old.tagPosition?.y != tagPosition?.y) {
      return true;
    }
    final oldH = old.headingDeg, newH = headingDeg;
    if (oldH != newH) {
      if (oldH == null || newH == null) return true;
      if ((oldH - newH).abs() >= 1.0) return true;
    }
    return false;
  }
}

// ── Info Bar ──────────────────────────────────────────────────────────────────

class _InfoBar extends StatelessWidget {
  final UwbPosition? position;
  final List<UwbAnchor> anchors;
  final double? headingDeg;
  final bool noRoute;

  const _InfoBar({
    required this.position,
    required this.anchors,
    required this.headingDeg,
    required this.noRoute,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final posText = position != null
        ? 'x ${position!.x.toStringAsFixed(1)}  y ${position!.y.toStringAsFixed(1)}'
        : l10n.uwbWaiting;

    final anchorTexts = anchors
        .where((a) => a.distanceMeters > 0)
        .map((a) => '${a.name}: ${a.distanceMeters.toStringAsFixed(1)}m')
        .join('   ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, size: 12, color: AppTheme.successColor),
          const SizedBox(width: 4),
          Text(posText,
              style: const TextStyle(
                  color: AppTheme.successColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(anchorTexts,
                style: const TextStyle(color: AppTheme.darkOnMuted, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
          if (noRoute)
            Text(l10n.uwbTapToNavigate,
                style:
                    const TextStyle(color: AppTheme.darkOnMuted, fontSize: 10)),
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
    final l10n = AppLocalizations.of(context)!;
    final color = state == UwbConnectionState.connected
        ? AppTheme.successColor
        : state == UwbConnectionState.connecting
            ? AppTheme.warningColor
            : Colors.red;
    final label = state == UwbConnectionState.connected
        ? l10n.uwbConnected
        : state == UwbConnectionState.connecting
            ? l10n.uwbSearching
            : l10n.uwbDisconnected;
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
