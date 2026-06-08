import 'dart:developer' as developer;
import 'package:logging/logging.dart';

/// Sets up logging for the entire application.
/// Logs will continue to be printed to the console.
void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Format: [LEVEL] ClassName: Message
    final message =
        '[${record.level.name}] ${record.loggerName}: ${record.message}';

    // Print to console (this will still show in debug mode)
    developer.log(
      record.message,
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );

    // Also print to stderr for visibility in all environments
    // ignore: avoid_print
    print(message);
  });
}

/// Gets a logger for the specified name (typically class name).
Logger getLogger(String name) {
  return Logger(name);
}
