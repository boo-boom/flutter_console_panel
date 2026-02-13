import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// 性能指标数据：FPS 与平均帧耗时。
class PerformanceMetrics {
  PerformanceMetrics({
    required this.fps,
    required this.averageFrameMs,
  });

  /// 估算的每秒帧数。
  final double fps;

  /// 平均每帧耗时（毫秒）。
  final double averageFrameMs;
}

/// 基于帧时间回调的简单性能监控，用于调试面板展示 FPS 等指标。
class PerformanceService {
  PerformanceService._internal();

  static final PerformanceService instance = PerformanceService._internal();

  /// 当前性能指标，UI 可监听此 notifier 刷新显示。
  final ValueNotifier<PerformanceMetrics> metrics = ValueNotifier<PerformanceMetrics>(
    PerformanceMetrics(fps: 0.0, averageFrameMs: 0.0),
  );

  /// 最近 N 帧的 FrameTiming 缓冲，用于计算平均帧耗时。
  final List<FrameTiming> _buffer = <FrameTiming>[];

  /// 是否已注册帧回调，避免重复注册。
  bool _started = false;

  /// 开始监听帧时间。可多次调用，仅首次生效。
  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// 停止监听帧时间并清空缓冲数据。
  void stop() {
    if (!_started) return;
    _started = false;
    try {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    } catch (_) {
      // 移除回调失败不影响业务。
    }
    _buffer.clear();
    metrics.value = PerformanceMetrics(fps: 0.0, averageFrameMs: 0.0);
  }

  /// 每帧结束时被调用，累加帧耗时并更新 FPS/平均帧时间。
  void _onTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
    const maxFrames = 120;
    if (_buffer.length > maxFrames) {
      _buffer.removeRange(0, _buffer.length - maxFrames);
    }

    if (_buffer.isEmpty) return;

    double totalMs = 0.0;
    for (final t in _buffer) {
      totalMs += t.totalSpan.inMicroseconds / 1000.0;
    }
    final double avgMs = totalMs / _buffer.length;
    final double fps = avgMs > 0.0 ? 1000.0 / avgMs : 0.0;

    metrics.value = PerformanceMetrics(
      fps: fps,
      averageFrameMs: avgMs,
    );
  }
}
