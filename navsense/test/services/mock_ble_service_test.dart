import 'package:flutter_test/flutter_test.dart';
import 'package:navsense/services/ble/mock_ble_service.dart';

void main() {
  group('MockBleService', () {
    late MockBleService ble;

    setUp(() {
      ble = MockBleService();
    });

    tearDown(() {
      ble.dispose();
    });

    test('starts disconnected', () {
      expect(ble.isConnected, isFalse);
    });

    test('isConnected becomes true after connect()', () async {
      await ble.connect('mock-device-001');
      expect(ble.isConnected, isTrue);
    });

    test('isConnected becomes false after disconnect()', () async {
      await ble.connect('mock-device-001');
      await ble.disconnect();
      expect(ble.isConnected, isFalse);
    });

    test('distanceStream emits values after connect()', () async {
      await ble.connect('mock-device-001');

      final values = <double>[];
      final sub = ble.distanceStream.listen(values.add);

      // Wait for at least two emissions
      await Future.delayed(const Duration(milliseconds: 1200));
      await sub.cancel();

      expect(values.length, greaterThanOrEqualTo(2));
      for (final v in values) {
        expect(v, inInclusiveRange(0.0, 30.0));
      }
    });

    test('scanDevices yields at least one device', () async {
      final devices = await ble.scanDevices().toList();
      expect(devices, isNotEmpty);
      expect(devices.first.name, contains('Beacon'));
    });

    test('BleDevice.signalQuality is clamped to 0.0–1.0', () async {
      final devices = await ble.scanDevices().toList();
      for (final d in devices) {
        expect(d.signalQuality, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
