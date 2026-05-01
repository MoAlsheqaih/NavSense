import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/uwb/uwb_service.dart';
import '../../services/uwb/uwb_position.dart';

class UwbStatusWidget extends StatefulWidget {
  const UwbStatusWidget({Key? key}) : super(key: key);

  @override
  State<UwbStatusWidget> createState() => _UwbStatusWidgetState();
}

class _UwbStatusWidgetState extends State<UwbStatusWidget> {
  late final UwbService _uwbService;
  UwbConnectionState _connState = UwbConnectionState.disconnected;
  UwbPosition? _lastPosition;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _uwbService = GetIt.I<UwbService>();

    _uwbService.connectionStateStream.stream.listen((state) {
      if (mounted) setState(() => _connState = state);
    });

    _uwbService.positionStream.listen((pos) {
      if (mounted) setState(() => _lastPosition = pos);
    });

    _startConnect();
  }

  void _startConnect() {
    _uwbService.connect().catchError((e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = _statusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon(), size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'UWB  ${_statusLabel(l10n)}',
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (_connState == UwbConnectionState.connected &&
                    _lastPosition != null)
                  Text(
                    'x: ${_lastPosition!.x.toStringAsFixed(2)}m  '
                    'y: ${_lastPosition!.y.toStringAsFixed(2)}m  '
                    '±${_lastPosition!.accuracy.toStringAsFixed(2)}m',
                    style: const TextStyle(
                        color: AppTheme.darkOnMuted, fontSize: 10),
                  ),
                if (_connState == UwbConnectionState.error &&
                    _errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (_connState == UwbConnectionState.error) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _errorMessage = null;
                  _connState = UwbConnectionState.disconnected;
                });
                _startConnect();
              },
              child: const Icon(Icons.refresh, size: 16, color: Colors.red),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (_connState) {
      case UwbConnectionState.connected:
        return AppTheme.successColor;
      case UwbConnectionState.connecting:
        return AppTheme.warningColor;
      case UwbConnectionState.error:
        return Colors.red;
      case UwbConnectionState.disconnected:
        return Colors.grey;
    }
  }

  IconData _statusIcon() {
    switch (_connState) {
      case UwbConnectionState.connected:
      case UwbConnectionState.connecting:
        return Icons.radar;
      case UwbConnectionState.error:
        return Icons.error_outline;
      case UwbConnectionState.disconnected:
        return Icons.radar_outlined;
    }
  }

  String _statusLabel(AppLocalizations l10n) {
    switch (_connState) {
      case UwbConnectionState.connected:
        return l10n.uwbConnected;
      case UwbConnectionState.connecting:
        return l10n.uwbSearching;
      case UwbConnectionState.error:
        return l10n.uwbStatusError;
      case UwbConnectionState.disconnected:
        return l10n.uwbDisconnected;
    }
  }
}
