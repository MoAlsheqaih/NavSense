import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_beacon/flutter_beacon.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/ble/ibeacon_parser.dart';
import '../../widgets/ble_status_widget.dart';

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({Key? key}) : super(key: key);

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage> {
  bool _isScanning = false;
  String _status = 'Press Scan to start';
  List<Beacon> _detectedBeacons = [];
  StreamSubscription<RangingResult>? _sub;
  int _scanCount = 0;
  final Set<String> _selectedBeaconNames = {
    BeaconConfig.beacon1.name,
    BeaconConfig.beacon2.name,
    BeaconConfig.beacon3.name,
    BeaconConfig.beacon4.name,
  };

  @override
  void dispose() {
    _stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _status = 'Initialising…';
      _isScanning = true;
      _detectedBeacons = [];
      _scanCount = 0;
    });

    if (kIsWeb) {
      setState(() {
        _status = 'BLE not supported on web';
        _isScanning = false;
      });
      return;
    }

    try {
      await flutterBeacon.initializeAndCheckScanning;

      final region = Region(
        identifier: 'navsense_scanner',
        proximityUUID: BeaconConfig.targetUuid,
        major: BeaconConfig.targetMajor,
        minor: BeaconConfig.targetMinor,
      );

      final selectedBeacons = BeaconConfig.allBeacons
          .where((b) => _selectedBeaconNames.contains(b.name))
          .toList();

      final regions = selectedBeacons
          .map((beacon) => Region(
                identifier: 'navsense_${beacon.name.toLowerCase()}',
                proximityUUID: beacon.uuid,
                major: beacon.major,
                minor: beacon.minor,
              ))
          .toList();

      _sub = flutterBeacon.ranging(regions).listen((result) {
        if (!mounted) return;
        setState(() {
          _scanCount++;
          _detectedBeacons = result.beacons;
          if (result.beacons.isNotEmpty) {
            _status = '${result.beacons.length} beacon(s) detected!';
          } else {
            _status = 'Scanning… ($_scanCount scans)';
          }
        });
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Error: $e';
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _stopScan() async {
    await _sub?.cancel();
    _sub = null;
    if (mounted) {
      setState(() {
        _isScanning = false;
        _status = 'Scan stopped';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beacon Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Beacon selection ──────────────────────────────────────
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Beacons to Scan:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.darkOnBg)),
                const SizedBox(height: 8),
                ...BeaconConfig.allBeacons.map((beacon) => BeaconSelectionCard(
                      beacon: beacon,
                      isSelected: _selectedBeaconNames.contains(beacon.name),
                      onTap: () {
                        setState(() {
                          if (_selectedBeaconNames.contains(beacon.name)) {
                            _selectedBeaconNames.remove(beacon.name);
                          } else {
                            _selectedBeaconNames.add(beacon.name);
                          }
                        });
                      },
                    )),
              ],
            ),
            const SizedBox(height: 24),

            // ── Status ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isScanning
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth_disabled,
                  color: _isScanning ? AppTheme.primaryColor : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _status,
                  style: TextStyle(
                    color: _detectedBeacons.isNotEmpty
                        ? AppTheme.successColor
                        : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Live beacon data ──────────────────────────────────────
            if (_detectedBeacons.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _detectedBeacons.length,
                  itemBuilder: (context, index) {
                    final beacon = _detectedBeacons[index];
                    final rows = [
                      ('UUID', beacon.proximityUUID),
                      ('Major', '${beacon.major}'),
                      ('Minor', '${beacon.minor}'),
                      ('RSSI', '${beacon.rssi} dBm'),
                      (
                        'Distance',
                        beacon.accuracy > 0
                            ? '${beacon.accuracy.toStringAsFixed(2)} m'
                            : 'Unknown'
                      ),
                      ('Proximity', beacon.proximity.name.toUpperCase()),
                    ];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _InfoCard(
                        title:
                            'Beacon ${index + 1} (${beacon.major}:${beacon.minor})',
                        highlight: true,
                        rows: rows,
                      ),
                    );
                  },
                ),
              )
            else if (_isScanning)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Looking for selected beacons…',
                        style: TextStyle(color: AppTheme.darkOnMuted)),
                  ],
                ),
              ),

            const Spacer(),

            // ── Scan button ───────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isScanning ? _stopScan : _startScan,
                icon: Icon(_isScanning ? Icons.stop : Icons.radar),
                label: Text(
                  _isScanning ? 'Stop Scan' : 'Start Scan',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isScanning ? Colors.red.shade800 : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final bool highlight;

  const _InfoCard({
    required this.title,
    required this.rows,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = highlight
        ? AppTheme.successColor.withValues(alpha: 0.5)
        : AppTheme.darkBorder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: highlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: highlight ? AppTheme.successColor : AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(r.$1,
                          style: const TextStyle(
                              color: AppTheme.darkOnMuted, fontSize: 12)),
                    ),
                    Expanded(
                      child: Text(r.$2,
                          style: const TextStyle(
                              color: AppTheme.darkOnBg,
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
