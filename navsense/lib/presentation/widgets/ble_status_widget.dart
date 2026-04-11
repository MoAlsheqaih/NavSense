import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/ble/ibeacon_parser.dart';

class BleStatusWidget extends StatelessWidget {
  final bool isConnected;
  final double? signalQuality; // 0.0–1.0, null = unknown
  final String connectedLabel;
  final String searchingLabel;

  const BleStatusWidget({
    Key? key,
    required this.isConnected,
    this.signalQuality,
    required this.connectedLabel,
    required this.searchingLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? (signalQuality != null && signalQuality! > 0.5
            ? AppTheme.successColor
            : AppTheme.warningColor)
        : Colors.grey;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
          color: color,
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          isConnected ? connectedLabel : searchingLabel,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        if (isConnected && signalQuality != null) ...[
          const SizedBox(width: 8),
          _SignalBars(quality: signalQuality!),
        ],
      ],
    );
  }
}

class _SignalBars extends StatelessWidget {
  final double quality;
  const _SignalBars({required this.quality});

  @override
  Widget build(BuildContext context) {
    final bars = (quality * 4).ceil().clamp(0, 4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final filled = i < bars;
        return Container(
          width: 4,
          height: 6.0 + i * 3,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: filled ? AppTheme.successColor : AppTheme.darkBorder,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class BeaconSelectionCard extends StatelessWidget {
  final BeaconInfo beacon;
  final bool isSelected;
  final VoidCallback onTap;

  const BeaconSelectionCard({
    Key? key,
    required this.beacon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? AppTheme.successColor.withValues(alpha: 0.5)
        : AppTheme.darkBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  beacon.name,
                  style: TextStyle(
                    color: isSelected
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, color: AppTheme.successColor),
                ],
              ],
            ),
            const SizedBox(height: 10),
            ...[
              ('UUID', beacon.uuid),
              ('Major', '${beacon.major}'),
              ('Minor', '${beacon.minor}'),
            ].map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
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
      ),
    );
  }
}
