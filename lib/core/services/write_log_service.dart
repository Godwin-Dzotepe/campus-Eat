import 'dart:async';

class WriteLogEntry {
  final DateTime timestamp;
  final String action;
  final String target;
  final bool success;
  final String? error;
  final int durationMs;

  WriteLogEntry({
    required this.timestamp,
    required this.action,
    required this.target,
    required this.success,
    required this.durationMs,
    this.error,
  });
}

class WriteLogService {
  static const int _maxEntries = 200;
  static final List<WriteLogEntry> _logs = [];
  static final StreamController<List<WriteLogEntry>> _controller =
      StreamController<List<WriteLogEntry>>.broadcast();

  static Stream<List<WriteLogEntry>> get stream => _controller.stream;

  static List<WriteLogEntry> get snapshot => List.unmodifiable(_logs);

  static Future<T> capture<T>({
    required String action,
    required String target,
    required Future<T> Function() task,
  }) async {
    final start = DateTime.now();
    try {
      final result = await task();
      _add(
        WriteLogEntry(
          timestamp: DateTime.now(),
          action: action,
          target: target,
          success: true,
          durationMs: DateTime.now().difference(start).inMilliseconds,
        ),
      );
      return result;
    } catch (error) {
      _add(
        WriteLogEntry(
          timestamp: DateTime.now(),
          action: action,
          target: target,
          success: false,
          durationMs: DateTime.now().difference(start).inMilliseconds,
          error: error.toString(),
        ),
      );
      rethrow;
    }
  }

  static void clear() {
    _logs.clear();
    _controller.add(List.unmodifiable(_logs));
  }

  static void _add(WriteLogEntry entry) {
    _logs.insert(0, entry);
    if (_logs.length > _maxEntries) {
      _logs.removeRange(_maxEntries, _logs.length);
    }
    _controller.add(List.unmodifiable(_logs));
  }
}
