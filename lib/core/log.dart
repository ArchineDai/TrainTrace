import 'package:flutter/foundation.dart';

/// 日志级别。[AppLog.minLevel] 以下整条丢弃。
enum LogLevel { debug, info, warn, error }

/// 全项目唯一的日志出口（移植自 weluck `core/log.dart`，去掉了网络体分块）。
///
/// 用 `debugPrint` 而不是 `print`（`avoid_print` 开着）或
/// `assert(() {...}())`（release 下整段不编译）。
class AppLog {
  AppLog._();

  /// 总开关。默认 debug 开 / release 关。
  static bool enabled = kDebugMode;

  static LogLevel minLevel = LogLevel.debug;

  static void d(String tag, String message) =>
      _emit(LogLevel.debug, tag, message);

  static void i(String tag, String message) =>
      _emit(LogLevel.info, tag, message);

  static void w(String tag, String message, [Object? error, StackTrace? stack]) =>
      _emit(LogLevel.warn, tag, message, error, stack);

  static void e(String tag, String message, [Object? error, StackTrace? stack]) =>
      _emit(LogLevel.error, tag, message, error, stack);

  static void _emit(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (!enabled || level.index < minLevel.index) return;
    final buf = StringBuffer(message);
    if (error != null) buf.write('\n    error: $error');
    if (stack != null) buf.write('\n$stack');
    debugPrint('${_mark(level)}/$tag: $buf');
  }

  static String _mark(LogLevel level) => switch (level) {
        LogLevel.debug => 'D',
        LogLevel.info => 'I',
        LogLevel.warn => 'W',
        LogLevel.error => 'E',
      };
}

/// 刻意静默降级的位置用它，不要写空 `catch`。
/// 留一行 warn 日志，排查时能看到"这里吞过一个错"。
void swallow(Object error, String label, [StackTrace? stack]) {
  AppLog.w('swallow', label, error, stack);
}
