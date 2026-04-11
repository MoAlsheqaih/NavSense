import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
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

  /// Called the moment the user starts dragging the origin dot.
  final VoidCallback? onDragStart;

  /// Called when the drag gesture ends.
  final VoidCallback? onDragEnd;

  /// When false, map taps are ignored (drag is still allowed).
  final bool tapEnabled;

  /// Live 60-fps position notifier — only the canvas repaints when this changes.
  final ValueListenable<Waypoint?>? liveOrigin;

  const SimulationMapWidget({
    super.key,
    this.origin,
    this.destination,
    this.routePlan,
    required this.onOriginChanged,
    required this.onDestinationChanged,
    required this.onRouteChanged,
    this.isInteractive = true,
    this.onDragStart,
    this.onDragEnd,
    this.tapEnabled = true,
    this.liveOrigin,
  });

  @override
  State<SimulationMapWidget> createState() => _SimulationMapWidgetState();
}

class _SimulationMapWidgetState extends State<SimulationMapWidget>
    with TickerProviderStateMixin {
  int _tapCount = 0;
  late RouteService _routeService;
  Timer? _routeCalculationTimer;
  Timer? _dragRouteTimer;
  bool _isDragging = false;
  bool _isComputingRoute = false;

  // Zoom and pan
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;

  // Drag position — drives efficient per-frame repaints via ValueListenableBuilder
  final ValueNotifier<Waypoint?> _dragOriginNotifier = ValueNotifier(null);

  // Fallback notifier used when liveOrigin is not provided (never fires).
  final ValueNotifier<Waypoint?> _noopPositionNotifier = ValueNotifier(null);

  // Dot pop animation on tap
  late AnimationController _dotAnimationController;
  late Animation<double> _dotScaleAnimation;

  final ValueNotifier<RouteCalculationResult> _routeResult = ValueNotifier(
    const RouteCalculationResult(),
  );

  // Floor dimensions (from FloorRouteDatasource)
  static const double _floorWidth = 29.0;
  static const double _floorHeight = 50.0;

  static final List<Offset> _corridorCells = [
    for (int x = 18; x <= 20; x++)
      for (int y = 0; y < 50; y++) Offset(x.toDouble(), y.toDouble()),
    for (int x = 0; x < 29; x++)
      for (int y = 22; y <= 25; y++) Offset(x.toDouble(), y.toDouble()),
    for (int x = 18; x < 29; x++)
      for (int y = 38; y <= 40; y++) Offset(x.toDouble(), y.toDouble()),
  ];

  static final List<Offset> _entranceCells = [
    const Offset(17, 42), const Offset(17, 43), const Offset(17, 44),
    const Offset(23, 41), const Offset(24, 41), const Offset(25, 41),
    const Offset(17, 27), const Offset(17, 28), const Offset(17, 29),
    const Offset(23, 37), const Offset(24, 37), const Offset(25, 37),
    const Offset(17, 18), const Offset(17, 19), const Offset(17, 20),
    const Offset(21, 18), const Offset(21, 19), const Offset(21, 20),
    const Offset(17, 12), const Offset(17, 13), const Offset(17, 14),
    const Offset(17, 4),  const Offset(17, 5),  const Offset(17, 6),
    const Offset(21, 4),  const Offset(21, 5),  const Offset(21, 6),
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
    _dragRouteTimer?.cancel();
    _dotAnimationController.dispose();
    _dragOriginNotifier.dispose();
    _noopPositionNotifier.dispose();
    _routeResult.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SimulationMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routePlan != widget.routePlan) {
      _routeResult.value = RouteCalculationResult(
        routePlan: widget.routePlan,
        isCalculating: _routeResult.value.isCalculating,
      );
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  ({double scale, double ox, double oy}) _layoutParams(Size size) {
    const double padding = 20.0;
    final availableWidth = size.width - padding * 2;
    final availableHeight = size.height - padding * 2;
    final scale =
        math.min(availableWidth / _floorWidth, availableHeight / _floorHeight);
    final ox = padding + (availableWidth - _floorWidth * scale) / 2;
    final oy = padding + (availableHeight - _floorHeight * scale) / 2;
    return (scale: scale, ox: ox, oy: oy);
  }

  // ── Coordinate conversions ─────────────────────────────────────────────────

  Offset _worldToScreen(double x, double y, Size size) {
    final p = _layoutParams(size);
    final base = Offset(p.ox + x * p.scale, p.oy + (_floorHeight - y) * p.scale);
    return base * _scale + _offset;
  }

  (double, double)? _screenToWorld(Offset screenPos, Size size) {
    final p = _layoutParams(size);
    final local = (screenPos - _offset) / _scale;
    final x = (local.dx - p.ox) / p.scale;
    final y = _floorHeight - (local.dy - p.oy) / p.scale;
    if (x < 0 || x > _floorWidth || y < 0 || y > _floorHeight) return null;
    return (x, y);
  }

  // ── Pan constraint ─────────────────────────────────────────────────────────

  void _constrainPan(Size size) {
    final p = _layoutParams(size);
    const double padding = 20.0;
    final renderedW = _floorWidth * p.scale * _scale;
    final renderedH = _floorHeight * p.scale * _scale;
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
    if (_isDragging || !widget.tapEnabled) return;

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

    // Use the live position (60fps notifier) as the tap target, fall back to widget.origin
    final effectiveOrigin = widget.liveOrigin?.value ?? widget.origin;
    if (effectiveOrigin != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(details.focalPoint);
      final originScreenPos =
          _worldToScreen(effectiveOrigin.x, effectiveOrigin.y, renderBox.size);
      if ((localPosition - originScreenPos).distance <= 40.0) {
        _isDragging = true;
        _dragOriginNotifier.value = effectiveOrigin;
        widget.onDragStart?.call();
      }
    }

    setState(() {});
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;

    if (_isDragging) {
      final localPosition = renderBox.globalToLocal(details.focalPoint);
      final worldPos = _screenToWorld(localPosition, renderBox.size);
      if (worldPos != null) {
        final newWaypoint = Waypoint(
          id: _dragOriginNotifier.value?.id ??
              'drag-${DateTime.now().millisecondsSinceEpoch}',
          name: _dragOriginNotifier.value?.name ?? 'Dragged Point',
          floor: 0,
          x: worldPos.$1.clamp(0.0, _floorWidth),
          y: worldPos.$2.clamp(0.0, _floorHeight),
        );
        // Update ValueNotifier — triggers repaint of only the painter subtree
        _dragOriginNotifier.value = newWaypoint;

        // Live route recomputation during drag (debounced, no loading flash)
        if (widget.destination != null) {
          _dragRouteTimer?.cancel();
          _dragRouteTimer = Timer(const Duration(milliseconds: 80), () {
            final dragWp = _dragOriginNotifier.value;
            if (_isDragging && dragWp != null) {
              _computeRoute(dragWp, widget.destination!, showLoading: false);
            }
          });
        }
      }
    } else {
      _scale = (_previousScale * details.scale).clamp(0.5, 3.0);
      _offset = _previousOffset + details.focalPointDelta;
      _constrainPan(renderBox.size);
      setState(() {});
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_isDragging) {
      _isDragging = false;
      widget.onDragEnd?.call(); // notify page drag is done before route recompute
      final finalWaypoint = _dragOriginNotifier.value;
      _dragOriginNotifier.value = null;

      if (finalWaypoint != null) {
        widget.onOriginChanged(finalWaypoint);
        if (widget.destination != null) {
          _computeRoute(finalWaypoint, widget.destination!);
        }
      }
    }

    if (_scale < 0.5) _scale = 0.5;
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
    _routeCalculationTimer = Timer(
      Duration(milliseconds: delay),
      () => _computeRoute(origin, destination),
    );
  }

  Future<void> _computeRoute(
    Waypoint origin,
    Waypoint destination, {
    bool showLoading = true,
  }) async {
    // Skip if another computation is already in progress
    if (_isComputingRoute) return;
    _isComputingRoute = true;

    if (showLoading) {
      _routeResult.value = RouteCalculationResult(
        routePlan: _routeResult.value.routePlan,
        isCalculating: true,
      );
    }

    try {
      final routePlan = await _routeService.computeRoute(origin, destination);
      _routeResult.value =
          RouteCalculationResult(routePlan: routePlan, isCalculating: false);
      widget.onRouteChanged(routePlan);
    } catch (_) {
      _routeResult.value =
          const RouteCalculationResult(routePlan: null, isCalculating: false);
      widget.onRouteChanged(null);
    } finally {
      _isComputingRoute = false;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: ClipRect(
        child: Stack(
          children: [
            // ── Map canvas ────────────────────────────────────────────────
            GestureDetector(
              onTapDown: widget.isInteractive ? _handleTap : null,
              onScaleStart: widget.isInteractive ? _handleScaleStart : null,
              onScaleUpdate: widget.isInteractive ? _handleScaleUpdate : null,
              onScaleEnd: widget.isInteractive ? _handleScaleEnd : null,
              child: ValueListenableBuilder<Waypoint?>(
                valueListenable: _dragOriginNotifier,
                builder: (_, dragOrigin, __) {
                  return ValueListenableBuilder<RouteCalculationResult>(
                    valueListenable: _routeResult,
                    builder: (_, routeResult, __) {
                      // Inner builder for the 60fps live position — only repaints
                      // the canvas, not the parent subtree.
                      final liveListenable =
                          widget.liveOrigin ?? _noopPositionNotifier;
                      return ValueListenableBuilder<Waypoint?>(
                        valueListenable: liveListenable,
                        builder: (_, livePos, __) {
                          final effectiveOrigin =
                              dragOrigin ?? livePos ?? widget.origin;
                          return RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _dotScaleAnimation,
                              builder: (_, __) => Transform.translate(
                                offset: _offset,
                                child: Transform.scale(
                                  scale: _scale,
                                  alignment: Alignment.topLeft,
                                  child: CustomPaint(
                                    painter: _MapPainter(
                                      origin: effectiveOrigin,
                                      destination: widget.destination,
                                      routePlan: routeResult.routePlan ??
                                          widget.routePlan,
                                      corridorCells: _corridorCells,
                                      entranceCells: _entranceCells,
                                      isDragging: _isDragging,
                                      dotScale: _dotScaleAnimation.value,
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // ── Loading overlay (Flutter widget — spins natively) ─────────
            ValueListenableBuilder<RouteCalculationResult>(
              valueListenable: _routeResult,
              builder: (_, result, __) {
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: result.isCalculating
                      ? Container(
                          key: const ValueKey('loading'),
                          color: Colors.black12,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.blue,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Calculating Route…',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        offset: Offset(0, 1),
                                        blurRadius: 3,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter ────────────────────────────────────────────────────────────────────

class _MapPainter extends FloorGridPainter {
  final Waypoint? origin;
  final Waypoint? destination;
  final RoutePlan? routePlan;
  final bool isDragging;
  final double dotScale;

  // Pre-allocated paints — never allocate inside paint() on a hot path.
  static final Paint _routeShadowPaint = Paint()
    ..color = Colors.red.withValues(alpha: 0.25)
    ..strokeWidth = 7
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static final Paint _routePaint = Paint()
    ..color = const Color(0xFFE53935)
    ..strokeWidth = 3.5
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static final Paint _waypointPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _dotFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _dotStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _dotGlowPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  _MapPainter({
    required this.origin,
    required this.destination,
    required this.routePlan,
    required List<Offset> corridorCells,
    required List<Offset> entranceCells,
    required this.isDragging,
    required this.dotScale,
  }) : super(
          floorWidth: 29.0,
          floorHeight: 50.0,
          corridorCells: corridorCells,
          entranceCells: entranceCells,
        );

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.origin != origin ||
      old.destination != destination ||
      old.routePlan != routePlan ||
      old.isDragging != isDragging ||
      old.dotScale != dotScale;

  @override
  void paint(Canvas canvas, Size size) {
    super.paint(canvas, size);

    // Route path — always visible, even during drag (shows ghost while recomputing)
    if (routePlan != null) _drawRoutePath(canvas, size);

    // Waypoint dots along the route
    if (routePlan != null) _drawWaypoints(canvas, size);

    // Destination (green)
    if (destination != null) {
      _drawDot(canvas, size, destination!, Colors.green, 12, false);
    }
    // Origin / drag position (blue)
    if (origin != null) {
      _drawDot(canvas, size, origin!, Colors.blue, 12, isDragging);
    }
    // Drag label
    if (isDragging && origin != null) {
      _drawDragFeedback(canvas, size, origin!);
    }
  }

  void _drawRoutePath(Canvas canvas, Size size) {
    final steps = routePlan!.steps;
    if (steps.length < 2) return;

    final path = Path();
    final first =
        worldToScreen(steps[0].waypoint.x, steps[0].waypoint.y, size);
    path.moveTo(first.dx, first.dy);

    for (int i = 1; i < steps.length; i++) {
      final pos =
          worldToScreen(steps[i].waypoint.x, steps[i].waypoint.y, size);
      path.lineTo(pos.dx, pos.dy);
    }

    // Shadow pass for visual depth
    canvas.drawPath(path, _routeShadowPaint);
    // Solid line pass
    canvas.drawPath(path, _routePaint);
  }

  void _drawWaypoints(Canvas canvas, Size size) {
    for (final step in routePlan!.steps) {
      final pos = worldToScreen(step.waypoint.x, step.waypoint.y, size);
      _waypointPaint.color = Colors.grey.shade400;
      canvas.drawCircle(pos, 3.5, _waypointPaint);
    }
  }

  void _drawDot(Canvas canvas, Size size, Waypoint waypoint, Color color,
      double radius, bool isBeingDragged) {
    final pos = worldToScreen(waypoint.x, waypoint.y, size);
    final r = radius * dotScale;

    if (isBeingDragged) {
      // Outer glow ring during drag
      _dotFillPaint.color = color.withValues(alpha: 0.18);
      canvas.drawCircle(pos, r * 2.2, _dotFillPaint);
    }

    // Filled circle
    _dotFillPaint.color = color;
    canvas.drawCircle(pos, r, _dotFillPaint);

    // White stroke border
    _dotStrokePaint.color = Colors.white;
    canvas.drawCircle(pos, r, _dotStrokePaint);

    if (isBeingDragged) {
      // Animated ripple ring
      _dotGlowPaint.color = color.withValues(alpha: 0.5);
      canvas.drawCircle(pos, r * 1.5, _dotGlowPaint);
    }
  }

  void _drawDragFeedback(Canvas canvas, Size size, Waypoint waypoint) {
    final pos = worldToScreen(waypoint.x, waypoint.y, size);

    _paintText(
      canvas,
      'DRAGGING',
      pos + const Offset(-25, -38),
      const TextStyle(
        color: Colors.blue,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    _paintText(
      canvas,
      '(${waypoint.x.toStringAsFixed(1)}, ${waypoint.y.toStringAsFixed(1)})',
      pos + const Offset(-28, 18),
      TextStyle(color: Colors.grey.shade700, fontSize: 10),
    );
  }

  void _paintText(Canvas canvas, String text, Offset offset, TextStyle style) {
    (TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout())
        .paint(canvas, offset);
  }
}
