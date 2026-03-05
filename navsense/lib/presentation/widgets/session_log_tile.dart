import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/session_log_model.dart';
import '../../domain/entities/navigation_session.dart';
import '../../domain/entities/session_event.dart';

class SessionLogTile extends StatefulWidget {
  final NavigationSession session;

  const SessionLogTile({Key? key, required this.session}) : super(key: key);

  @override
  State<SessionLogTile> createState() => _SessionLogTileState();
}

class _SessionLogTileState extends State<SessionLogTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final eventCount = session.events.length;
    final duration = session.navigationDuration;
    final calcMs = session.routeCalculationMs;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.route, color: AppTheme.primaryColor),
            title: Text(
              session.sessionId.substring(0, 8).toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            ),
            subtitle: Text(
              '${session.startTime.toLocal().toString().substring(0, 19)}  •  $eventCount events',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (duration != null)
                  Chip(
                    label: Text(_formatDuration(duration)),
                    backgroundColor: AppTheme.successColor.withOpacity(0.15),
                    labelStyle: const TextStyle(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ],
            ),
          ),
          if (_expanded) ...[
            if (calcMs != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Route calculation: $calcMs ms',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const Divider(),
            ...session.events.map((e) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 10,
                      color: AppTheme.primaryColor),
                  title: Text(e.type.jsonKey,
                      style: const TextStyle(fontSize: 13)),
                  trailing: Text(
                    e.timestamp.toLocal().toString().substring(11, 23),
                    style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: Colors.grey),
                  ),
                )),
            Padding(
              padding: const EdgeInsets.all(8),
              child: OutlinedButton.icon(
                onPressed: () => _showJson(context),
                icon: const Icon(Icons.code, size: 16),
                label: const Text('View JSON'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showJson(BuildContext context) {
    final model = SessionLogModel.fromSession(widget.session);
    final pretty =
        const JsonEncoder.withIndent('  ').convert(model.toJson());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Session JSON'),
        content: SingleChildScrollView(
          child: SelectableText(
            pretty,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }
}
