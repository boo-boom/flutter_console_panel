import 'package:flutter/foundation.dart';

import '../../core/debug_config.dart';

/// 调试面板使用的日志级别。
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

extension LogLevelLabel on LogLevel {
  /// 用于 UI 显示的短标签（如 DEBUG、INFO）。
  String get label {
    switch (this) {
      case LogLevel.debug:
        return '调试';
      case LogLevel.info:
        return '信息';
      case LogLevel.warning:
        return '警告';
      case LogLevel.error:
        return '错误';
    }
  }
}

/// 单条日志条目。
class LogEntry {
  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    this.tag,
    this.error,
    this.stackTrace,
  });

  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final String? tag;
  final Object? error;
  final StackTrace? stackTrace;
}

/// 日志采集服务：接管 debugPrint / FlutterError，将日志写入内存供 UI 展示。
class LogsService {
  LogsService._internal();

  static final LogsService instance = LogsService._internal();

  final ValueNotifier<List<LogEntry>> _entriesNotifier = ValueNotifier<List<LogEntry>>(<LogEntry>[]);

  ValueListenable<List<LogEntry>> get entries => _entriesNotifier;

  int _maxEntries = 1000;
  bool _initialized = false;

  DebugPrintCallback? _originalDebugPrint;
  FlutterExceptionHandler? _originalFlutterErrorHandler;

  /// 首次调用时接管 debugPrint 与 FlutterError.onError，之后调用无效果。
  void ensureInitialized({required DebugConfig config}) {
    if (_initialized) return;
    _initialized = true;

    _maxEntries = config.maxLogEntries;

    // 包装 debugPrint，在原有输出基础上写入内存缓冲；任何异常都会被吞掉避免影响业务。
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      try {
        if (message != null) {
          log(
            message,
            level: LogLevel.debug,
          );
        }
      } catch (_) {
        // 日志模块自身错误不影响原本输出。
      }
      try {
        _originalDebugPrint?.call(message, wrapWidth: wrapWidth);
      } catch (_) {
        // 保证不会因为调试模块导致业务崩溃。
      }
    };

    // 接管框架层错误，记录到日志并继续交给原有处理器；内部异常全部吞掉。
    _originalFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      try {
        log(
          details.exceptionAsString(),
          level: LogLevel.error,
          error: details.exception,
          stackTrace: details.stack,
        );
      } catch (_) {
        // ignore
      }
      try {
        final previous = _originalFlutterErrorHandler;
        if (previous != null) {
          previous(details);
        } else {
          FlutterError.dumpErrorToConsole(details);
        }
      } catch (_) {
        // 最坏情况也只影响错误输出，不影响业务逻辑。
      }
    };
  }

  /// 写入一条日志（供 DebugLog 或业务直接调用）。
  void log(
    String message, {
    LogLevel level = LogLevel.debug,
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      tag: tag,
      error: error,
      stackTrace: stackTrace,
    );

    final List<LogEntry> current = List<LogEntry>.from(_entriesNotifier.value)..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    _entriesNotifier.value = current;
  }

  /// 清空当前所有日志。
  void clear() {
    _entriesNotifier.value = const <LogEntry>[];
  }
}

/// 供业务侧使用的便捷日志 API（带级别与 tag）。
class DebugLog {
  const DebugLog._();

  static void d(String message, {String? tag}) {
    LogsService.instance.log(message, level: LogLevel.debug, tag: tag);
  }

  static void i(String message, {String? tag}) {
    LogsService.instance.log(message, level: LogLevel.info, tag: tag);
  }

  static void w(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    LogsService.instance.log(
      message,
      level: LogLevel.warning,
      tag: tag,
      error: error,
      stackTrace: stack,
    );
  }

  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stack,
  }) {
    LogsService.instance.log(
      message,
      level: LogLevel.error,
      tag: tag,
      error: error,
      stackTrace: stack,
    );
  }
}
