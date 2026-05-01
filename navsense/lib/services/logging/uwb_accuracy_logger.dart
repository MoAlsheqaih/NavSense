import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Appends one CSV row per UWB position fix for offline accuracy analysis.
/// Format: timestamp_ms, x, y, accuracy_m, anchor_count
class UwbAccuracyLogger {
  UwbAccuracyLogger._();
  static final UwbAccuracyLogger instance = UwbAccuracyLogger._();

  File? _file;
  bool _headerWritten = false;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    final name =
        'uwb_accuracy_${DateTime.now().millisecondsSinceEpoch}.csv';
    _file = File('${dir.path}/$name');
    return _file!;
  }

  Future<void> log({
    required double x,
    required double y,
    required double accuracyMeters,
    required int anchorCount,
  }) async {
    try {
      final file = await _getFile();
      if (!_headerWritten) {
        await file.writeAsString(
            'timestamp_ms,x,y,accuracy_m,anchor_count\n');
        _headerWritten = true;
      }
      final row =
          '${DateTime.now().millisecondsSinceEpoch},'
          '${x.toStringAsFixed(4)},'
          '${y.toStringAsFixed(4)},'
          '${accuracyMeters.toStringAsFixed(4)},'
          '$anchorCount\n';
      await file.writeAsString(row, mode: FileMode.append);
    } catch (_) {}
  }

  /// Returns the path of the current log file, or null if nothing logged yet.
  Future<String?> get filePath async {
    if (_file == null) return null;
    return _file!.path;
  }

  /// Closes the current file so the next [log] call starts a fresh one.
  void reset() {
    _file = null;
    _headerWritten = false;
  }
}
