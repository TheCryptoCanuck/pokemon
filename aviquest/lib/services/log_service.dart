import 'package:logging/logging.dart';

/// Centralized logging helpers.
///
/// Usage:
///   final _log = LogService.create('MyClass');
///   _log.info('something happened');
///   _log.severe('oh no', error, stackTrace);
///
/// Root listener is configured once in main() via [LogService.init].
class LogService {
  LogService._();

  /// Create a named logger for a class or module.
  static Logger create(String name) => Logger(name);

  /// Initialise root logging. Call once from main().
  static void init({Level level = Level.INFO}) {
    Logger.root.level = level;
    Logger.root.onRecord.listen(_defaultHandler);
  }

  static void _defaultHandler(LogRecord record) {
    // ignore: avoid_print — intentional for debug output
    final buffer = StringBuffer(
      '[${record.level.name}] ${record.loggerName}: ${record.message}',
    );
    if (record.error != null) buffer.write('\n  Error: ${record.error}');
    if (record.stackTrace != null) buffer.write('\n  ${record.stackTrace}');
    // Using print because debugPrint may not be available in non-Flutter contexts (e.g. tests).
    // ignore: avoid_print
    print(buffer);
  }
}
