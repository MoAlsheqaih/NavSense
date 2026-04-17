import 'dart:async';
import 'package:flutter/material.dart';
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
  UwbConnectionState _connState = UwbConnectionState.disconnected;
  String? _rawData;
  StreamSubscription? _posSub;
  StreamSubscription? _connSub;
  Timer? _rawTimer;

  @override
  void initState() {
    super.initState();
    _uwbService = GetIt.I<UwbService>();
    _connState = _uwbService.isConnected
        ? UwbConnectionState.connected
        : UwbConnectionState.disconnected;
    _position = _uwbService.lastPosition;

    _posSub = _uwbService.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _connSub = _uwbService.connectionStateStream.stream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });

    // Poll raw BLE data for debugging
    _rawTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final raw = (_uwbService is BleUwbService)
          ? (_uwbService as BleUwbService).lastRawData
          : null;
      if (raw != _rawData) setState(() => _rawData = raw);
    });
  }

  @override
  void dispose() {
    _rawTimer?.cancel();
    _posSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('UWB Live Map'),
        actions: [
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
              ),
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
                style: const TextStyle(color: Colors.green, fontSize: 10, fontFamily: 'monospace'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _InfoPanel(position: _position, anchors: _uwbService.anchors),
        ],
      ),
    );
  }
}

// ── Map Canvas ────────────────────────────────────────────────────────────────

class _UwbMapCanvas extends StatelessWidget {
  final List<UwbAnchor> anchors;
  final UwbPosition? tagPosition;

  const _UwbMapCanvas({required this.anchors, required this.tagPosition});

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
          painter: _MapPainter(anchors: anchors, tagPosition: tagPosition),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final List<UwbAnchor> anchors;
  final UwbPosition? tagPosition;

  _MapPainter({required this.anchors, required this.tagPosition});

  @override
  void paint(Canvas canvas, Size size) {
    if (anchors.isEmpty) return;

    const padding = 48.0;
    final drawW = size.width - padding * 2;
    final drawH = size.height - padding * 2;

    // Compute bounding box of anchors
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

    // Centre the drawing
    final offsetX = padding + (drawW - spaceW * scale) / 2;
    final offsetY = padding + (drawH - spaceH * scale) / 2;

    Offset toCanvas(double x, double y) => Offset(
          offsetX + (x - minX) * scale,
          offsetY + (maxY - y) * scale, // flip Y so y=0 is at bottom
        );

    // Grid lines
    final gridPaint = Paint()
      ..color = AppTheme.darkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (var gx = 0.0; gx <= spaceW; gx += 1.0) {
      final p = toCanvas(minX + gx, minY);
      final p2 = toCanvas(minX + gx, maxY);
      canvas.drawLine(p, p2, gridPaint);
    }
    for (var gy = 0.0; gy <= spaceH; gy += 1.0) {
      final p = toCanvas(minX, minY + gy);
      final p2 = toCanvas(maxX, minY + gy);
      canvas.drawLine(p, p2, gridPaint);
    }

    // Anchor distance rings (subtle dashed look via thin stroke)
    for (final anchor in anchors) {
      if (anchor.distanceMeters > 0) {
        final center = toCanvas(anchor.x, anchor.y);
        final radius = anchor.distanceMeters * scale;
        canvas.drawCircle(
          center,
          radius,
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

      canvas.drawCircle(pos, 10,
          Paint()..color = AppTheme.primaryColor.withValues(alpha: 0.9));
      canvas.drawCircle(
          pos, 10,
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

    // Tag marker
    if (tagPosition != null) {
      final tagPos = toCanvas(tagPosition!.x, tagPosition!.y);

      // Outer glow ring
      canvas.drawCircle(tagPos, 14,
          Paint()
            ..color = AppTheme.successColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Solid dot
      canvas.drawCircle(tagPos, 10,
          Paint()..color = AppTheme.successColor);
      canvas.drawCircle(tagPos, 10,
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

  void _drawLabel(Canvas canvas, String text, Color color, double fontSize,
      Offset center, double yOffset, {bool bold = false}) {
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
      old.tagPosition != tagPosition || old.anchors != anchors;
}

// ── Info Panel ────────────────────────────────────────────────────────────────

class _InfoPanel extends StatelessWidget {
  final UwbPosition? position;
  final List<UwbAnchor> anchors;

  const _InfoPanel({required this.position, required this.anchors});

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
              const Icon(Icons.location_on, size: 14, color: AppTheme.successColor),
              const SizedBox(width: 6),
              Text(
                position != null
                    ? 'Tag:  x = ${position!.x.toStringAsFixed(3)} m    '
                      'y = ${position!.y.toStringAsFixed(3)} m    '
                      '±${position!.accuracy.toStringAsFixed(3)} m'
                    : 'Tag:  waiting for data...',
                style: const TextStyle(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
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
