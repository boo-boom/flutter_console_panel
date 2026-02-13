import 'package:flutter/foundation.dart';

/// 调试面板的全局配置。
class DebugConfig {
  /// 是否启用调试面板。默认与 kDebugMode 一致，仅在调试模式生效，防止误上线。
  final bool enabled;

  /// 是否在 Profile 构建下显示面板。
  final bool showInProfileMode;

  /// 是否在 Release 构建下显示面板。
  final bool showInReleaseMode;

  /// 内存中保留的日志条数上限。
  final int maxLogEntries;

  /// 内存中保留的网络请求条数上限。
  final int maxNetworkEntries;

  /// 在 UI 中需要脱敏的请求头 key（如 authorization、cookie）。
  final List<String> maskSensitiveHeaders;

  /// 在 UI 中需要脱敏的 JSON 字段名。
  final List<String> maskSensitiveKeys;

  const DebugConfig({
    bool? enabled,
    this.showInProfileMode = false,
    this.showInReleaseMode = false,
    this.maxLogEntries = 1000,
    this.maxNetworkEntries = 300,
    this.maskSensitiveHeaders = const ['authorization', 'cookie', 'set-cookie'],
    this.maskSensitiveKeys = const [
      'password',
      'token',
      'accessToken',
      'refreshToken',
    ],
  }) : enabled = enabled ?? kDebugMode;
}
