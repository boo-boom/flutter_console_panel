import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'debug_config.dart';
import 'debug_overlay_entry.dart';
import '../modules/logs/logs_service.dart';
import '../modules/network/network_service.dart';
import '../modules/performance/performance_service.dart';
import '../modules/shared_prefs/shared_prefs_service.dart';

/// 调试面板内部控制器，持有可见性与配置等状态。
class DebugPanelController {
  DebugPanelController._internal();

  static final DebugPanelController instance = DebugPanelController._internal();

  /// 当前使用的配置，可在 init 时覆盖。
  DebugConfig config = const DebugConfig();

  final ValueNotifier<bool> _panelVisible = ValueNotifier<bool>(false);

  ValueListenable<bool> get panelVisible => _panelVisible;

  /// 根据构建模式与 config 判断是否应显示调试入口。
  bool get isEnabled {
    if (!config.enabled) return false;
    if (kDebugMode) return true;
    if (kProfileMode) return config.showInProfileMode;
    if (kReleaseMode) return config.showInReleaseMode;
    return false;
  }

  /// 显示调试面板。
  void showPanel() {
    if (!isEnabled) return;
    _panelVisible.value = true;
  }

  /// 关闭调试面板。
  void hidePanel() {
    _panelVisible.value = false;
  }

  /// 切换面板显示/隐藏。
  void togglePanel() {
    if (_panelVisible.value) {
      hidePanel();
    } else {
      showPanel();
    }
  }
}

/// 调试面板对外入口，用于在应用中集成悬浮球与多 Tab 面板。
///
/// 典型用法（main.dart）：
/// ```dart
/// runApp(DebugPanel.init(child: const MyApp(), config: const DebugConfig()));
/// ```
class DebugPanel {
  DebugPanel._();

  static final DebugPanelController _controller = DebugPanelController.instance;

  static DebugPanelController get instance => _controller;

  /// 初始化调试面板并包裹根 Widget；若当前构建模式未启用则直接返回 [child]。
  static Widget init({
    required Widget child,
    DebugConfig config = const DebugConfig(),
  }) {
    _controller.config = config;
    if (!_controller.isEnabled) {
      return child;
    }

    // 初始化日志、网络、性能等模块，内部异常全部吞掉，避免影响业务。
    try {
      LogsService.instance.ensureInitialized(config: config);
    } catch (_) {}
    try {
      NetworkService.instance.applyConfig(config);
    } catch (_) {}
    try {
      PerformanceService.instance.start();
    } catch (_) {}
    try {
      SharedPrefsService.instance.loadAll();
    } catch (_) {}

    return DebugOverlayRoot(
      controller: _controller,
      child: child,
    );
  }

  /// 以代码方式打开调试面板。
  static void showPanel() => _controller.showPanel();

  /// 以代码方式关闭调试面板。
  static void hidePanel() => _controller.hidePanel();

  /// 切换调试面板的显示状态。
  static void togglePanel() => _controller.togglePanel();

  /// 为 Dio 实例添加拦截器，自动记录请求/响应到 Network Tab。
  static void attachDio(Dio dio) => NetworkService.instance.attachDio(dio, config: _controller.config);

  /// 包装 http.Client，使通过该 client 发出的请求被记录到 Network Tab。
  static http.Client wrapHttpClient(http.Client client) => NetworkService.instance.wrapHttpClient(client, config: _controller.config);
}
