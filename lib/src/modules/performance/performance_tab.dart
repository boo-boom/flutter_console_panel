import 'package:flutter/material.dart';

import 'performance_service.dart';

/// 性能 Tab：显示当前 FPS 与平均帧耗时，用于快速判断卡顿。
class PerformanceTab extends StatelessWidget {
  const PerformanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ValueListenableBuilder<PerformanceMetrics>(
        valueListenable: PerformanceService.instance.metrics,
        builder: (context, metrics, _) {
          final theme = Theme.of(context);
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'FPS',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                metrics.fps.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: metrics.fps >= 55
                      ? Colors.green
                      : (metrics.fps >= 30 ? Colors.orange : Colors.red),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '平均帧耗时: ${metrics.averageFrameMs.toStringAsFixed(2)} 毫秒',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              const Text(
                '数值为近似值，仅供快速排查。',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }
}
