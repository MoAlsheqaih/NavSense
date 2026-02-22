import 'package:flutter/material.dart';

import '../../../domain/entities/navigation_session.dart';
import '../../../services/logging/session_logging_service.dart';

class SessionHistoryViewModel extends ChangeNotifier {
  final SessionLoggingService _loggingService;

  SessionHistoryViewModel(this._loggingService);

  List<NavigationSession> _sessions = [];
  bool _loading = false;

  List<NavigationSession> get sessions => _sessions;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _sessions = await _loggingService.getAllSessions();
    _loading = false;
    notifyListeners();
  }
}
