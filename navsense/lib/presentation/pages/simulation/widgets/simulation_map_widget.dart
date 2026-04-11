import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../domain/entities/route_plan.dart';
import '../../../../domain/entities/waypoint.dart';
import '../../../../services/routing/route_service.dart';
import 'floor_grid_painter.dart';

class RouteCalculationResult {
  final RoutePlan? routePlan;
  final bool isCalculating;

  const RouteCalculationResult({
    this.routePlan,
    this.isCalculating = false,
  });
}

class SimulationMapWidget extends StatefulWidget {
  final Waypoint? origin;
  final Waypoint? destination;
  final RoutePlan? routePlan;
  final Function(Waypoint) onOriginChanged;
  final Function(Waypoint) onDestinationChanged;
  final Function(RoutePlan?) onRouteChanged;
  final bool isInteractive;

  const SimulationMapWidget({
    super.key,
    this.origin,
    this.destination,
    this.routePlan,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onRouteChanged,
    this.isInteractive = true,
  });

  @override
  State<SimulationMapWidget> createState() => _SimulationMapWidgetState();
}

class _SimulationMapWidgetState extends State<SimulationMapWidget>
    with TickerProviderStateMixin {
  int _tapCount = 0;
  late RouteService _routeService;
  Timer? _routeCalculationTimer;
  bool _isDragging = false;
  Waypoint? _draggedOrigin;

  // Zoom and pan
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  Offset? _dragStartPosition;

  // Animation controller — drives dot pop on tap only; disposed when idle
  // to avoid unnecessary rebuild ticks from AnimatedBuilder.
  late AnimationController _dotAnimationController;
  late Animation<double> _dotScaleAnimation;

  final ValueNotifier<RouteCalculationResult> _routeResult = ValueNotifier(
    const RouteCalculationResult(),
  );

  // Floor dimensions (from FloorRouteDatasource)
  static const double _floorWidth = 29.0;
  static const double _floorHeight = 50.0;

  // FIX: static final so these lists are shared across all widget instances,
  // not re-allocated on every build.
  static final List<Offset> _corridorCells = [
    for (int x = 18; x <= 20; x++)
      for (int y = 0; y < 50; y++) Offset(x.toDouble(), y.toDouble()),
    for (int x = 0; x < 29; x++)
      for (int y = 22; y <= 25; y++) Offset(x.toDouble(), y.toDouble()),
    for (int x = 18; x < 29; x++)
      for (int y = 38; y <= 40; y++) Offset(x.toDouble(), y.toDouble()),
  ];

  static final List<Offset> _entranceCells = [
    const Offset(17, 42),
    const Offset(17, 43),
    const Offset(17, 44),
    const Offset(23, 41),
    const Offset(24, 41),
    const Offset(25, 41),
    const Offset(17, 27),
    const Offset(17, 28),
    const Offset(17, 29),
    const Offset(23, 37),
    const Offset(24, 37),
    const Offset(25, 37),
    const Offset(17, 18),
    const Offset(17, 19),
    const Offset(17, 20),
    const Offset(21, 18),
    const Offset(21, 19),
    const Offset(21, 20),
    const Offset(17, 12),
    const Offset(17, 13),
    const Offset(17, 14),
    const Offset(17, 4),
    const Offset(17, 5),
    const Offset(17, 6),
    const Offset(21, 4),
    const Offset(21, 5),
    const Offset(21, 6),
  ];

  @override
  void initState() {
    super.initState();
    _routeService = sl<RouteService>();

    _dotAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _dotScaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _dotAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _routeCalculationTimer?.cancel();
    _dotAnimationController.dispose();
    _routeResult.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SimulationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // FIX: when the parent pushes a new routePlan, sync it into the notifier
    // so the painter always renders the current plan, not a stale one.
    if (oldWidget.routePlan != widget.routePlan) {
      _routeResult.value = RouteCalculationResult(
        routePlan: widget.routePlan,
        isCalculating: _routeResult.value.isCalculating,
      );
    }
  }

  // ── Layout helper ─────────────────────────────────────────────────────────

  /// Computes the shared scale + origin used by both world↔screen conversions.
  /// Returns (scale, originX, originY) where originX/Y is the top-left pixel
  /// of the floor rect inside the container.
  ({double scale, double ox, double oy}) _layoutParams(Size size) {
    const double padding = 20.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;
    final scale =
        math.min(availableWidth / _floorWidth, availableHeight / _floorHeight);
    final floorWidthPx = _floorWidth * scale;
    final floorHeightPx = _floorHeight * scale;
    final ox = padding + (availableWidth - floorWidthPx) / 2;
    final oy = padding + (availableHeight - floorHeightPx) / 2;
    return (scale: scale, ox: ox, oy: oy);
  }

  // ── Coordinate conversions ─────────────────────────────────────────────────

  Offset _worldToScreen(double x, double y, Size size) {
    final p = _layoutParams(size);
    final base =
        Offset(p.ox + x * p.scale, p.oy + (_floorHeight - y) * p.scale);
    return base * _scale + _offset;
  }

  Offset _baseWorldToScreen(double x, double y, Size size) {
    final p = _layoutParams(size);
    return Offset(p.ox + x * p.scale, p.oy + (_floorHeight - y) * p.scale);
  }

  (double, double)? _screenToWorld(Offset screenPos, Size size) {
    // Undo the interactive zoom/pan, then convert base coords.
    return _baseScreenToWorld((screenPos - _offset) / _scale, size);
  }

  (double, double)? _baseScreenToWorld(Offset screenPos, Size size) {
    final p = _layoutParams(size);
    final x = (screenPos.dx - p.ox) / p.scale;
    final y = _floorHeight - (screenPos.dy - p.oy) / p.scale;
    if (x < 0 || x > _floorWidth || y < 0 || y > _floorHeight) return null;
    return (x, y);
  }

  // ── Pan constraint ─────────────────────────────────────────────────────────

  void _constrainPan() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    // FIX: constrain against the *rendered* floor pixel size, not raw world
    // units. The floor is drawn at _layoutParams(size).scale px per unit.
    final p = _layoutParams(size);
    final renderedW = _floorWidth * p.scale * _scale;
    final renderedH = _floorHeight * p.scale * _scale;

    const double padding = 20.0;
    final maxDx =
        (renderedW - size.width + padding * 2).clamp(0.0, double.infinity);
    final maxDy =
        (renderedH - size.height + padding * 2).clamp(0.0, double.infinity);

    _offset = Offset(
      _offset.dx.clamp(-maxDx, 0),
      _offset.dy.clamp(-maxDy, 0),
    );
  }

  // ── Gesture handlers ───────────────────────────────────────────────────────

  void _handleTap(TapDownDetails details) {
    if (_isDragging) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final worldPos = _screenToWorld(localPosition, renderBox.size);
    if (worldPos == null) return;

    final waypoint = Waypoint(
      id: 'tap-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Tapped Point',
      floor: 0,
      x: worldPos.$1,
      y: worldPos.$2,
    );

    _dotAnimationController
        .forward()
        .then((_) => _dotAnimationController.reverse());

    _tapCount++;
    if (_tapCount == 1) {
      widget.onOriginChanged(waypoint);
    } else if (_tapCount == 2) {
      widget.onDestinationChanged(waypoint);

      // FIX: guard against origin being null before force-unwrapping.
      // Use the freshly tapped point as destination and the last known origin.
      final origin = widget.origin;
      if (origin != null) {
        _computeRouteDebounced(origin, waypoint);
      }
      _tapCount = 0;
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _previousScale = _scale;
    _previousOffset = _offset;

    if (widget.origin != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(details.focalPoint);
      final originScreenPos =
          _worldToScreen(widget.origin!.x, widget.origin!.y, renderBox.size);
      // No need to convert worldPos — we only need the screen distance.
      if ((localPosition - originScreenPos).distance <= 40.0) {
        _isDragging = true;
        _draggedOrigin = widget.origin;
      }
    }

    setState(() {});
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_isDragging && widget.origin != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(details.focalPoint);
      final worldPos = _screenToWorld(localPosition, renderBox.size);
      if (worldPos != null && _draggedOrigin != null) {
        // Update dragged origin position immediately (no rebuild for smooth dragging)
        _draggedOrigin = Waypoint(
          id: _draggedOrigin!.id,
          name: _draggedOrigin!.name,
          floor: 0,
          x: worldPos.$1.clamp(0.0, _floorWidth),
          y: worldPos.$2.clamp(0.0, _floorHeight),
        );
      }
    } else {
      _scale = (_previousScale * details.scale).clamp(0.5, 3.0);
      _offset = _previousOffset + details.focalPointDelta;
      _constrainPan();
      setState(() {});
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    // End dragging
    if (_isDragging) {
      _isDragging = false;
      _dragStartPosition = null;
      // Update origin and compute route after drag ends
      if (_draggedOrigin != null && widget.destination != null) {
        widget.onOriginChanged(_draggedOrigin!);
        _computeRoute(_draggedOrigin!, widget.destination!);
      }
      _draggedOrigin = null;
    }

    // Ensure minimum scale
    if (_scale < 0.5) {
      _scale = 0.5;
    }
    setState(() {});
  }

  void resetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
    });
  }

  // ── Route computation ─────────────────────────────────────────────────────

  void _computeRouteDebounced(Waypoint origin, Waypoint destination,
      {int delay = 150}) {
    _routeCalculationTimer?.cancel();
    _routeCalculationTimer = Timer(Duration(milliseconds: delay),
        () => _computeRoute(origin, destination));
  }

  Future<void> _computeRoute(Waypoint origin, Waypoint destination) async {
    _routeResult.value = RouteCalculationResult(
      routePlan: _routeResult.value.routePlan,
      isCalculating: true,
    );
    try {
      final routePlan = await _routeService.computeRoute(origin, destination);
      _routeResult.value =
          RouteCalculationResult(routePlan: routePlan, isCalculating: false);
      widget.onRouteChanged(routePlan);
    } catch (_) {
      _routeResult.value =
          const RouteCalculationResult(routePlan: null, isCalculating: false);
      widget.onRouteChanged(null);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // FIX: ValueListenableBuilder wraps both branches so the notifier drives
    // repaints even in non-interactive mode. AnimatedBuilder sits inside only
    // in interactive mode — avoids needless ticks otherwise.
    return Container(
      color: Colors.grey.shade50,
      child: ClipRect(
        child: ValueListenableBuilder<RouteCalculationResult>(
          valueListenable: _routeResult,
          builder: (context, routeResult, _) {
            final painter = _MapPainter(
              origin: widget.origin,
              destination: widget.destination,
              routePlan: routeResult.routePlan ?? widget.routePlan,
              corridorCells: _corridorCells,
              entranceCells: _entranceCells,
              isDragging: _isDragging,
              dotScale: _dotScaleAnimation.value,
              isCalculating: routeResult.isCalculating,
            );

            final content = Transform(
              transform: Matrix4.identity()
                ..translate(_offset.dx, _offset.dy)
                ..scale(_scale),
              child: CustomPaint(
                painter: painter,
                child: const SizedBox.expand(),
              ),
            );

            if (!widget.isInteractive) return content;

            return GestureDetector(
              onTapDown: _handleTap,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: _handleScaleUpdate,
              onScaleEnd: _handleScaleEnd,
              // FIX: AnimatedBuilder only wraps the interactive branch —
              // non-interactive mode never subscribes to animation ticks.
              child: AnimatedBuilder(
                animation: _dotScaleAnimation,
                builder: (_, __) => Transform(
                  transform: Matrix4.identity()
                    ..translate(_offset.dx, _offset.dy)
                    ..scale(_scale),
                  child: CustomPaint(
                    painter: _MapPainter(
                      origin: _draggedOrigin ?? widget.origin,
                      destination: widget.destination,
                      routePlan: routeResult.routePlan ?? widget.routePlan,
                      corridorCells: _corridorCells,
                      entranceCells: _entranceCells,
                      isDragging: _isDragging,
                      dotScale: _dotScaleAnimation.value,
                      isCalculating: routeResult.isCalculating,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────

class _MapPainter extends FloorGridPainter {
  final Waypoint? origin;
  final Waypoint? destination;
  final RoutePlan? routePlan;
  final bool isDragging;
  final double dotScale;
  final bool isCalculating;

  // FIX: pre-allocate Paint objects here instead of allocating inside paint()
  // on every frame.
  static final Paint _routePaint = Paint()
    ..color = Colors.red
    ..strokeWidth = 3
    ..style = PaintingStyle.stroke;

  static final Paint _waypointPaint = Paint()..style = PaintingStyle.fill;

  _MapPainter({
    required this.origin,
    required this.destination,
    required this.routePlan,
    required List<Offset> corridorCells,
    required List<Offset> entranceCells,
    required this.isDragging,
    required this.dotScale,
    required this.isCalculating,
  }) : super(
          floorWidth: 29.0,
          floorHeight: 50.0,
          corridorCells: corridorCells,
          entranceCells: entranceCells,
        );

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);

    // Draw route path first (bottom layer) - hide during drag to avoid confusion
    if (routePlan != null && !isDragging) _drawRoutePath(canvas, size);

    // Draw intermediate waypoint dots
    _drawWaypoints(canvas, size);

    // Draw origin and destination on top
    if (destination != null) {
      _drawDot(canvas, size, destination!, Colors.green, 12, false);
    }
    if (origin != null) {
      _drawDot(canvas, size, origin!, Colors.blue, 12, isDragging);
    }
    if (isDragging && origin != null) {
      _drawDragFeedback(canvas, size, origin!);
    }

    // FIX: draw loading indicator LAST so it overlays everything, but still
    // shows the existing route and dots beneath the semi-transparent overlay.
    if (isCalculating) _drawLoadingIndicator(canvas, size);
  }

  void _drawRoutePath(Canvas canvas, Size size) {
    if (routePlan!.steps.isEmpty) return;

    final path = Path();
    for (int i = 0; i < routePlan!.steps.length - 1; i++) {
      final startPos = worldToScreen(
          routePlan!.steps[i].waypoint.x, routePlan!.steps[i].waypoint.y, size);
      final endPos = worldToScreen(routePlan!.steps[i + 1].waypoint.x,
          routePlan!.steps[i + 1].waypoint.y, size);
      path.moveTo(startPos.dx, startPos.dy);
      path.lineTo(endPos.dx, endPos.dy);
    }

    // FIX: removed duplicate `paint` variable — only one Paint is needed.
    _drawDashedPath(canvas, path, _routePaint, dashWidth: 8, dashSpace: 4);
  }

  void _drawWaypoints(Canvas canvas, Size size) {
    for (final step in routePlan?.steps ?? const []) {
      _waypointPaint.color = Colors.grey.shade400;
      final pos = worldToScreen(step.waypoint.x, step.waypoint.y, size);
      canvas.drawCircle(pos, 4, _waypointPaint);
    }
  }

  void _drawDot(Canvas canvas, Size size, Waypoint waypoint, Color color,
      double radius, bool isBeingDragged) {
    final pos = worldToScreen(waypoint.x, waypoint.y, size);
    final effectiveRadius = radius * dotScale;

    final paint = Paint()..style = PaintingStyle.fill;

    if (isBeingDragged) {
      paint.color = color.withValues(alpha: 0.3);
      canvas.drawCircle(pos, effectiveRadius * 1.5, paint);
    }

    paint.color = color;
    canvas.drawCircle(pos, effectiveRadius, paint);

    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(pos, effectiveRadius, paint);

    if (isBeingDragged) {
      paint
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawCircle(pos, effectiveRadius * 1.3, paint);
    }
  }

  void _drawLoadingIndicator(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Semi-transparent overlay — lower alpha so underlying route remains
    // visible and users have context while the new route calculates.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 30.0),
      0,
      math.pi * 1.5,
      false,
      Paint()
        ..color = Colors.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Calculating Route...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2)
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    textPainter.paint(canvas, center + Offset(-textPainter.width / 2, 50));
  }

  void _drawDragFeedback(Canvas canvas, Size size, Waypoint waypoint) {
    final pos = worldToScreen(waypoint.x, waypoint.y, size);

    (TextPainter(
      text: const TextSpan(
        text: 'DRAGGING',
        style: TextStyle(
            color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(canvas, pos + const Offset(-25, -35));

    (TextPainter(
      text: TextSpan(
        text:
            '(${waypoint.x.toStringAsFixed(1)}, ${waypoint.y.toStringAsFixed(1)})',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(canvas, pos + const Offset(-30, 18));
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint,
      {double dashWidth = 8, double dashSpace = 4}) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final end =
            math.min(distance + (draw ? dashWidth : dashSpace), metric.length);
        if (draw) {
          final a = metric.getTangentForOffset(distance);
          final b = metric.getTangentForOffset(end);
          if (a != null && b != null) {
            canvas.drawLine(a.position, b.position, paint);
          }
        }
        distance = end;
        draw = !draw;
      }
    }
  }
}
