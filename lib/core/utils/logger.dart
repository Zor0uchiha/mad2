import "dart:developer" as dev;

class Logger {
  static void d(String message, [String? tag]) {
    dev.log(message, name: tag ?? "Bookstr");
  }

  static void e(String message, [Object? error, StackTrace? stackTrace, String? tag]) {
    dev.log(message, name: tag ?? "Bookstr", error: error, stackTrace: stackTrace);
  }

  static void w(String message, [String? tag]) {
    dev.log("WARNING: $message", name: tag ?? "Bookstr");
  }
}
