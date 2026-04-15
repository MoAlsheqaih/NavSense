import 'dart:math';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';

class UwbPositionCalculator {
  static UwbPosition? calculatePosition({
    required List<UwbAnchor> anchors,
    required String tagId,
  }) {
    if (anchors.length < 3) {
      return null;
    }

    final distances = anchors.map((a) => a.distanceMeters).toList();
    final x1 = anchors[0].x;
    final y1 = anchors[0].y;
    final x2 = anchors[1].x;
    final y2 = anchors[1].y;
    final x3 = anchors[2].x;
    final y3 = anchors[2].y;

    final r1 = distances[0];
    final r2 = distances[1];
    final r3 = distances[2];

    final A = 2 * x2 - 2 * x1;
    final B = 2 * y2 - 2 * y1;
    final C = r1 * r1 - r2 * r2 - x1 * x1 - y1 * y1 + x2 * x2 + y2 * y2;

    final D = 2 * x3 - 2 * x2;
    final E = 2 * y3 - 2 * y2;
    final F = r2 * r2 - r3 * r3 - x2 * x2 - y2 * y2 + x3 * x3 + y3 * y3;

    final den = 2 * (x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2));

    if (den.abs() < 0.0001) {
      return _calculateWithNoiseFallback(anchors, tagId);
    }

    final xVal = (C * E - F * B) / (A * E - D * B);
    final yVal = (C * D - F * A) / (B * D - A * E);

    final accuracy = _estimateAccuracy(distances, anchors);

    return UwbPosition(
      tagId: tagId,
      x: xVal,
      y: yVal,
      timestamp: DateTime.now(),
      accuracy: accuracy,
    );
  }

  static UwbPosition? _calculateWithNoiseFallback(
      List<UwbAnchor> anchors, String tagId) {
    double sumX = 0;
    double sumY = 0;
    for (final anchor in anchors) {
      final angle = Random().nextDouble() * 2 * pi;
      final dist = anchor.distanceMeters;
      sumX += anchor.x + cos(angle) * dist;
      sumY += anchor.y + sin(angle) * dist;
    }

    final xVal = sumX / anchors.length;
    final yVal = sumY / anchors.length;

    return UwbPosition(
      tagId: tagId,
      x: xVal,
      y: yVal,
      timestamp: DateTime.now(),
      accuracy: 1.0,
    );
  }

  static double _estimateAccuracy(
      List<double> distances, List<UwbAnchor> anchors) {
    if (distances.isEmpty || anchors.isEmpty) return 1.0;

    double sumError = 0;
    for (int i = 0; i < distances.length; i++) {
      final dx = anchors[i].x;
      final dy = anchors[i].y;
      final estimated = sqrt(dx * dx + dy * dy);
      sumError += (distances[i] - estimated).abs();
    }

    final avgError = sumError / distances.length;
    return max(0.05, avgError);
  }

  static List<UwbAnchor> createDefaultAnchors({
    double floorWidth = 50.0,
    double floorHeight = 29.0,
    double margin = 2.0,
  }) {
    return [
      UwbAnchor(
        id: 'anchor_1',
        name: 'UWB Anchor A1',
        x: margin,
        y: margin,
      ),
      UwbAnchor(
        id: 'anchor_2',
        name: 'UWB Anchor A2',
        x: floorWidth - margin,
        y: margin,
      ),
      UwbAnchor(
        id: 'anchor_3',
        name: 'UWB Anchor A3',
        x: floorWidth / 2,
        y: floorHeight - margin,
      ),
    ];
  }
}
