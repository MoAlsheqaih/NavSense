import 'package:flutter/material.dart';
import 'package:navsense/l10n/app_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../services/logging/session_logging_service.dart';
import '../../widgets/session_log_tile.dart';
import 'session_history_viewmodel.dart';

class SessionHistoryPage extends StatelessWidget {
  const SessionHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionHistoryViewModel(
        GetIt.I<SessionLoggingService>(),
      )..load(),
      child: const _SessionHistoryView(),
    );
  }
}

class _SessionHistoryView extends StatelessWidget {
  const _SessionHistoryView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vm = context.watch<SessionHistoryViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: vm.load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: vm.loading
          ? const Center(child: CircularProgressIndicator())
          : vm.sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        l10n.historyEmpty,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: vm.sessions.length,
                  itemBuilder: (_, i) =>
                      SessionLogTile(session: vm.sessions[i]),
                ),
    );
  }
}
