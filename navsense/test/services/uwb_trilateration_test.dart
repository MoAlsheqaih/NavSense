import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/services/uwb/uwb_anchor.dart';
import 'package:navsense/services/uwb/uwb_trilateration.dart';

void main() {
  group('UwbPositionCalculator', () {
    test('calculates position with 3 anchors', () {
      final anchors = [
        const UwbAnchor(
            id: 'a1', name: 'Anchor 1', x: 0, y: 0, distanceMeters: 5),
        const UwbAnchor(
            id: 'a2', name: 'Anchor 2', x: 10, y: 0, distanceMeters: 5),
        const UwbAnchor(
            id: 'a3', name: 'Anchor 3', x: 5, y: 10, distanceMeters: 5),
      ];

      final position = UwbPositionCalculator.calculatePosition(
        anchors: anchors,
        tagId: 'tag_001',
      );

      expect(position, isNotNull);
      expect(position!.tagId, equals('tag_001'));
      expect(position.x, inInclusiveRange(-1.0, 11.0));
      expect(position.y, inInclusiveRange(-1.0, 11.0));
      expect(position.accuracy, greaterThan(0.0));
    });

    test('returns null with less than 3 anchors', () {
      final anchors = [
        const UwbAnchor(
            id: 'a1', name: 'Anchor 1', x: 0, y: 0, distanceMeters: 5),
        const UwbAnchor(
            id: 'a2', name: 'Anchor 2', x: 10, y: 0, distanceMeters: 5),
      ];

      final position = UwbPositionCalculator.calculatePosition(
        anchors: anchors,
        tagId: 'tag_001',
      );

      expect(position, isNull);
    });

    test('createDefaultAnchors returns 3 anchors', () {
      final anchors = UwbPositionCalculator.createDefaultAnchors(
        floorWidth: 50.0,
        floorHeight: 30.0,
      );

      expect(anchors.length, equals(3));
      expect(anchors[0].id, equals('anchor_1'));
      expect(anchors[1].id, equals('anchor_2'));
      expect(anchors[2].id, equals('anchor_3'));
    });
  });
}
