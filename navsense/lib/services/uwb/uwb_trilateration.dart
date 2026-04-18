import 'dart:math';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_position.dart';

class UwbPositionCalculator {
  static const double _minDist = 0.1;
  static const double _maxDist = 30.0;

  static UwbPosition? calculatePosition({
    required List<UwbAnchor> anchors,
    required String tagId,
  }) {
    if (anchors.length < 2) return null;

    // Clamp distances to physically plausible range
    final clamped = anchors
        .map((a) => a.copyWith(
            distanceMeters: a.distanceMeters.clamp(_minDist, _maxDist)))
        .toList();

    if (clamped.length == 2) {
      return _calculateFrom2(clamped, tagId);
    }

    return _calculateFrom3(clamped, tagId);
  }

  static UwbPosition? _calculateFrom3(List<UwbAnchor> anchors, String tagId) {
    final x1 = anchors[0].x, y1 = anchors[0].y, r1 = anchors[0].distanceMeters;
    final x2 = anchors[1].x, y2 = anchors[1].y, r2 = anchors[1].distanceMeters;
    final x3 = anchors[2].x, y3 = anchors[2].y, r3 = anchors[2].distanceMeters;

    final A = 2 * x2 - 2 * x1;
    final B = 2 * y2 - 2 * y1;
    final C = r1 * r1 - r2 * r2 - x1 * x1 - y1 * y1 + x2 * x2 + y2 * y2;

    final D = 2 * x3 - 2 * x2;
    final E = 2 * y3 - 2 * y2;
    final F = r2 * r2 - r3 * r3 - x2 * x2 - y2 * y2 + x3 * x3 + y3 * y3;

    final det = A * E - D * B;
    if (det.abs() < 0.001) {
      // Anchors nearly collinear — fall back to weighted centroid
      return _weightedCentroid(anchors, tagId);
    }

    final x = (C * E - F * B) / det;
    final y = (A * F - D * C) / det;

    return UwbPosition(
      tagId: tagId,
      x: x,
      y: y,
      timestamp: DateTime.now(),
      accuracy: _residualError(anchors, x, y),
    );
  }

  static UwbPosition? _calculateFrom2(List<UwbAnchor> anchors, String tagId) {
    return _weightedCentroid(anchors, tagId);
  }

  // Inverse-distance weighted centroid — best estimate without enough anchors
  static UwbPosition _weightedCentroid(List<UwbAnchor> anchors, String tagId) {
    double sumW = 0, sumX = 0, sumY = 0;
    for (final a in anchors) {
      final w = 1.0 / max(a.distanceMeters, 0.01);
      sumW += w;
      sumX += a.x * w;
      sumY += a.y * w;
    }
    return UwbPosition(
      tagId: tagId,
      x: sumX / sumW,
      y: sumY / sumW,
      timestamp: DateTime.now(),
      accuracy: 2.0,
    );
  }

  // Trilateration residual: how well the computed position fits the distances
  static double _residualError(List<UwbAnchor> anchors, double x, double y) {
    double sumSq = 0;
    for (final a in anchors) {
      final dx = x - a.x, dy = y - a.y;
      final computed = sqrt(dx * dx + dy * dy);
      final err = computed - a.distanceMeters;
      sumSq += err * err;
    }
    return max(0.01, sqrt(sumSq / anchors.length));
  }

  static List<UwbAnchor> createDefaultAnchors({
    double floorWidth = 50.0,
    double floorHeight = 29.0,
    double margin = 2.0,
  }) {
    return [
      UwbAnchor(id: 'anchor_1', name: 'UWB Anchor A1', x: margin, y: margin),
      UwbAnchor(
          id: 'anchor_2',
          name: 'UWB Anchor A2',
          x: floorWidth - margin,
          y: margin),
      UwbAnchor(
          id: 'anchor_3',
          name: 'UWB Anchor A3',
          x: floorWidth / 2,
          y: floorHeight - margin),
    ];
  }
}
