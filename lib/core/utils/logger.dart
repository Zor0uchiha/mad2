class Logger {
  static void info(String message) {
    // ignore: avoid_print
    print("[INFO] $message");
  }

  static void warning(String message) {
    // ignore: avoid_print
    print("[WARNING] $message");
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    // ignore: avoid_print
    print("[ERROR] $message${error != null ? ": $error" : ""}");
    if (stackTrace != null) {
      // ignore: avoid_print
      print(stackTrace);
    }
  }

  static void debug(String message) {
    // ignore: avoid_print
    print("[DEBUG] $message");
  }
}
