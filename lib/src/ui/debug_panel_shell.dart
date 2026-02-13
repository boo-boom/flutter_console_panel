import 'package:flutter/material.dart';

import '../modules/logs/logs_tab.dart';
import '../modules/network/network_tab.dart';
import '../modules/state/state_tab.dart';
import '../modules/performance/performance_tab.dart';
import '../modules/actions/actions_tab.dart';
import '../modules/shared_prefs/shared_prefs_tab.dart';

/// 调试面板外壳：顶部标题与关闭按钮，下方为 Logs / Network / State / Perf / Actions 五个 Tab。
class DebugPanelShell extends StatelessWidget {
  const DebugPanelShell({
    super.key,
    required this.onClose,
  });

  /// 点击关闭按钮时的回调。
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            height: constraints.maxHeight * 0.6,
            width: constraints.maxWidth,
            child: Material(
              color: theme.colorScheme.surface.withAlpha(250),
              elevation: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: DefaultTabController(
                length: 6,
                child: Column(
                  children: [
                    _buildHeader(context),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.center,
                      tabs: [
                        Tab(text: '日志'),
                        Tab(text: '网络'),
                        Tab(text: '状态'),
                        Tab(text: '性能'),
                        Tab(text: '存储'),
                        Tab(text: '操作'),
                      ],
                    ),
                    const Expanded(
                      child: TabBarView(
                        children: [
                          LogsTab(),
                          NetworkTab(),
                          StateTab(),
                          PerformanceTab(),
                          SharedPrefsTab(),
                          ActionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 面板顶部：拖拽条、标题、关闭按钮。
  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.bug_report, size: 22),
          const SizedBox(width: 8),
          Text(
            '调试面板',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          Semantics(
            label: '关闭调试面板',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.close),
              tooltip: null,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }
}
