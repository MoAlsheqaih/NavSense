import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:navsense/services/uwb/uwb_anchor.dart';

class FloorGridPainter extends CustomPainter {
  final double floorWidth;
  final double floorHeight;
  final double cellSize;
  final List<Offset> corridorCells;
  final List<Offset> entranceCells;
  final List<UwbAnchor> uwbAnchors;

  FloorGridPainter({
    this.floorWidth = 29.0,
    this.floorHeight = 50.0,
    this.cellSize = 10.0,
    this.corridorCells = const [],
    this.entranceCells = const [],
    this.uwbAnchors = const [],
  });

  // Room definitions with boundaries and names
  static const List<Map<String, dynamic>> _rooms = [
    {
      'name': 'Room 1',
      'bounds': Rect.fromLTWH(0, 40, 17, 10), // x:0-17, y:40-50
      'color': Color(0xFFE3F2FD), // Light blue
      'textPos': Offset(8.5, 45),
    },
    {
      'name': 'Room 2',
      'bounds': Rect.fromLTWH(21, 40, 8, 10), // x:21-28, y:40-50
      'color': Color(0xFFF3E5F5), // Light purple
      'textPos': Offset(25, 45),
    },
    {
      'name': 'Room 3',
      'bounds': Rect.fromLTWH(0, 26, 17, 14), // x:0-17, y:26-40
      'color': Color(0xFFE8F5E8), // Light green
      'textPos': Offset(8.5, 33),
    },
    {
      'name': 'Room 4',
      'bounds': Rect.fromLTWH(21, 26, 8, 14), // x:21-28, y:26-40
      'color': Color(0xFFFFF8E1), // Light yellow
      'textPos': Offset(25, 33),
    },
    {
      'name': 'Room 5',
      'bounds': Rect.fromLTWH(0, 14, 17, 12), // x:0-17, y:14-26
      'color': Color(0xFFFFEBEE), // Light red
      'textPos': Offset(8.5, 20),
    },
    {
      'name': 'Room 6',
      'bounds': Rect.fromLTWH(21, 14, 8, 12), // x:21-28, y:14-26
      'color': Color(0xFFF3E5F5), // Light purple
      'textPos': Offset(25, 20),
    },
    {
      'name': 'Room 7',
      'bounds': Rect.fromLTWH(0, 8, 17, 6), // x:0-17, y:8-14
      'color': Color(0xFFE3F2FD), // Light blue
      'textPos': Offset(8.5, 11),
    },
    {
      'name': 'Room 8',
      'bounds': Rect.fromLTWH(0, 0, 17, 8), // x:0-17, y:0-8
      'color': Color(0xFFE8F5E8), // Light green
      'textPos': Offset(8.5, 4),
    },
    {
      'name': 'Room 9',
      'bounds': Rect.fromLTWH(21, 0, 8, 14), // x:21-28, y:0-14
      'color': Color(0xFFFFF8E1), // Light yellow
      'textPos': Offset(25, 7),
    },
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Add padding to prevent edge overflow
    const double padding = 20.0;

    // Calculate scale to fit the floor in the available space with padding
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);
    final scaleX = availableWidth / floorWidth;
    final scaleY = availableHeight / floorHeight;
    final scale = math.min(scaleX, scaleY);

    // Center the floor with padding
    final floorWidthPx = floorWidth * scale;
    final floorHeightPx = floorHeight * scale;
    final offsetX = padding + (availableWidth - floorWidthPx) / 2;
    final offsetY = padding + (availableHeight - floorHeightPx) / 2;

    // Draw in proper order for visual hierarchy
    _drawBackground(canvas, size);
    _drawRooms(canvas, scale, offsetX, offsetY);
    _drawCorridors(canvas, scale, offsetX, offsetY);
    _drawWalls(canvas, scale, offsetX, offsetY);
    _drawEntrances(canvas, scale, offsetX, offsetY);
    _drawRoomLabels(canvas, scale, offsetX, offsetY);
    _drawGrid(canvas, scale, offsetX, offsetY);
    _drawUwbAnchors(canvas, scale, offsetX, offsetY);
  }

  void _drawUwbAnchors(
      Canvas canvas, double scale, double offsetX, double offsetY) {
    for (final anchor in uwbAnchors) {
      final center = Offset(
        offsetX + anchor.x * scale,
        offsetY + (floorHeight - anchor.y) * scale,
      );

      // Draw anchor circle
      final circlePaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, scale * 0.4, circlePaint);

      // Draw anchor border
      final borderPaint = Paint()
        ..color = const Color(0xFF1565C0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, scale * 0.4, borderPaint);

      // Draw anchor label
      final textPainter = TextPainter(
        text: TextSpan(
          text: anchor.id.replaceAll('anchor_', 'A'),
          style: TextStyle(
            color: const Color(0xFF1565C0),
            fontSize: (scale * 0.5).clamp(1.0, 14.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          center.dx - textPainter.width / 2,
          center.dy - scale * 0.8,
        ),
      );
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF8F9FA)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawRooms(Canvas canvas, double scale, double offsetX, double offsetY) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final room in _rooms) {
      final bounds = room['bounds'] as Rect;
      final color = room['color'] as Color;

      paint.color = color;
      final rect = Rect.fromLTWH(
        offsetX + bounds.left * scale,
        offsetY + (floorHeight - bounds.bottom) * scale,
        bounds.width * scale,
        bounds.height * scale,
      );
      canvas.drawRect(rect, paint);

      // Draw room border
      final borderPaint = Paint()
        ..color = color.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(rect, borderPaint);
    }
  }

  void _drawCorridors(
      Canvas canvas, double scale, double offsetX, double offsetY) {
    final paint = Paint()
      ..color = const Color(0xFFE8F4F8)
      ..style = PaintingStyle.fill;

    // Draw main vertical corridor
    final verticalCorridor = Rect.fromLTWH(
      offsetX + 18 * scale,
      offsetY,
      3 * scale,
      floorHeight * scale,
    );
    canvas.drawRect(verticalCorridor, paint);

    // Draw horizontal corridors
    final horizontalCorridor1 = Rect.fromLTWH(
      offsetX + 18 * scale,
      offsetY + (floorHeight - 25) * scale,
      (floorWidth - 18) * scale,
      4 * scale,
    );
    canvas.drawRect(horizontalCorridor1, paint);

    final horizontalCorridor2 = Rect.fromLTWH(
      offsetX,
      offsetY + (floorHeight - 26) * scale,
      floorWidth * scale,
      2 * scale,
    );
    canvas.drawRect(horizontalCorridor2, paint);

    final horizontalCorridor3 = Rect.fromLTWH(
      offsetX + 18 * scale,
      offsetY + (floorHeight - 40) * scale,
      (floorWidth - 18) * scale,
      3 * scale,
    );
    canvas.drawRect(horizontalCorridor3, paint);
  }

  void _drawWalls(Canvas canvas, double scale, double offsetX, double offsetY) {
    final paint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();

    // Draw outer perimeter
    path.moveTo(offsetX, offsetY);
    path.lineTo(offsetX + floorWidth * scale, offsetY);
    path.lineTo(offsetX + floorWidth * scale, offsetY + floorHeight * scale);
    path.lineTo(offsetX, offsetY + floorHeight * scale);
    path.close();

    // Draw room dividing walls
    // Vertical wall separating left and right sections
    path.moveTo(offsetX + 18 * scale, offsetY);
    path.lineTo(offsetX + 18 * scale, offsetY + floorHeight * scale);

    // Horizontal dividing walls
    path.moveTo(offsetX, offsetY + (floorHeight - 8) * scale);
    path.lineTo(offsetX + 18 * scale, offsetY + (floorHeight - 8) * scale);

    path.moveTo(offsetX, offsetY + (floorHeight - 14) * scale);
    path.lineTo(offsetX + 18 * scale, offsetY + (floorHeight - 14) * scale);

    path.moveTo(offsetX, offsetY + (floorHeight - 26) * scale);
    path.lineTo(
        offsetX + floorWidth * scale, offsetY + (floorHeight - 26) * scale);

    path.moveTo(offsetX, offsetY + (floorHeight - 40) * scale);
    path.lineTo(offsetX + 18 * scale, offsetY + (floorHeight - 40) * scale);

    canvas.drawPath(path, paint);
  }

  void _drawEntrances(
      Canvas canvas, double scale, double offsetX, double offsetY) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50)
      ..style = PaintingStyle.fill;

    for (final entrance in entranceCells) {
      final center = Offset(
        offsetX + entrance.dx * scale + scale / 2,
        offsetY + (floorHeight - entrance.dy - 0.5) * scale,
      );
      canvas.drawCircle(center, scale * 0.3, paint);
    }
  }

  void _drawRoomLabels(
      Canvas canvas, double scale, double offsetX, double offsetY) {
    for (final room in _rooms) {
      final textPos = room['textPos'] as Offset;
      final name = room['name'] as String;

      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: const Color(0xFF263238),
            fontSize: (scale * 0.8).clamp(1.0, 24.0),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      final position = Offset(
        offsetX + textPos.dx * scale - textPainter.width / 2,
        offsetY + (floorHeight - textPos.dy) * scale - textPainter.height / 2,
      );
      textPainter.paint(canvas, position);
    }
  }

  void _drawGrid(Canvas canvas, double scale, double offsetX, double offsetY) {
    final paint = Paint()
      ..color = const Color(0xFFB0BEC5).withValues(alpha: 0.2)
      ..strokeWidth = 0.5;

    // Draw grid lines every 5 units for better readability
    for (double x = 0; x <= floorWidth; x += 5.0) {
      canvas.drawLine(
        Offset(offsetX + x * scale, offsetY),
        Offset(offsetX + x * scale, offsetY + floorHeight * scale),
        paint,
      );
    }

    for (double y = 0; y <= floorHeight; y += 5.0) {
      canvas.drawLine(
        Offset(offsetX, offsetY + y * scale),
        Offset(offsetX + floorWidth * scale, offsetY + y * scale),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FloorGridPainter oldDelegate) {
    return oldDelegate.floorWidth != floorWidth ||
        oldDelegate.floorHeight != floorHeight ||
        oldDelegate.corridorCells != corridorCells ||
        oldDelegate.entranceCells != entranceCells ||
        oldDelegate.uwbAnchors != uwbAnchors;
  }

  Offset worldToScreen(double x, double y, Size size) {
    // Add padding to prevent edge overflow
    const double padding = 20.0;

    // Calculate scale to fit the floor in the available space with padding
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);
    final scaleX = availableWidth / floorWidth;
    final scaleY = availableHeight / floorHeight;
    final scale = math.min(scaleX, scaleY);

    // Center the floor with padding
    final floorWidthPx = floorWidth * scale;
    final floorHeightPx = floorHeight * scale;
    final offsetX = padding + (availableWidth - floorWidthPx) / 2;
    final offsetY = padding + (availableHeight - floorHeightPx) / 2;

    return Offset(
      offsetX + x * scale,
      offsetY + (floorHeight - y) * scale,
    );
  }

  (double, double)? screenToWorld(Offset screenPos, Size size) {
    // Add padding to prevent edge overflow
    const double padding = 20.0;

    // Calculate scale to fit the floor in the available space with padding
    final availableWidth = size.width - (padding * 2);
    final availableHeight = size.height - (padding * 2);
    final scaleX = availableWidth / floorWidth;
    final scaleY = availableHeight / floorHeight;
    final scale = math.min(scaleX, scaleY);

    // Center the floor with padding
    final floorWidthPx = floorWidth * scale;
    final floorHeightPx = floorHeight * scale;
    final offsetX = padding + (availableWidth - floorWidthPx) / 2;
    final offsetY = padding + (availableHeight - floorHeightPx) / 2;

    final x = (screenPos.dx - offsetX) / scale;
    final y = floorHeight - (screenPos.dy - offsetY) / scale;

    if (x < 0 || x > floorWidth || y < 0 || y > floorHeight) {
      return null;
    }
    return (x, y);
  }
}
