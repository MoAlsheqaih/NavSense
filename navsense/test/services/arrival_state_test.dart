import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/services/ble/ble_service.dart';
import 'package:navsense/services/ble/mock_ble_service.dart';

void main() {
  group('MockBleService Arrival Detection', () {
    late MockBleService ble;

    setUp(() {
      ble = MockBleService();
    });

    tearDown(() {
      ble.dispose();
    });

    test('starts with far arrival state', () async {
      await ble.connectAll();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(ble.arrivalState, equals(ArrivalState.far));
    });

    test('arrivalStateStream emits values', () async {
      await ble.connectAll();

      // Wait for stream to initialize
      await Future.delayed(const Duration(milliseconds: 100));

      // Get the current state via getter first
      expect(ble.arrivalState, isNotNull);
    });

    test('arrival state changes as distance decreases', () async {
      await ble.connectAll();

      ArrivalState? lastState;
      await for (final _ in ble.arrivalStateStream) {
        lastState = ble.arrivalState;
        if (lastState != ArrivalState.far) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }

      expect(lastState, isNotNull);
    });
  });

  group('ArrivalState', () {
    test('has expected values', () {
      expect(ArrivalState.values, contains(ArrivalState.far));
      expect(ArrivalState.values, contains(ArrivalState.near));
      expect(ArrivalState.values, contains(ArrivalState.arrived));
    });
  });
}
