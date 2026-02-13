import 'package:flutter/material.dart';

import 'actions_service.dart';

/// 动作 Tab：列出应用注册的自定义调试动作，点击执行并显示结果。
class ActionsTab extends StatefulWidget {
  const ActionsTab({super.key});

  @override
  State<ActionsTab> createState() => _ActionsTabState();
}

class _ActionsTabState extends State<ActionsTab> {
  bool _running = false;
  String? _runningId;

  /// 每个 action 的最近一次执行结果（成功/失败信息）。
  final Map<String, _ActionResult> _results = {};

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ActionsService.instance,
      builder: (context, _) {
        final actions = ActionsService.instance.actions;
        if (actions.isEmpty) {
          return const Center(
            child: Text('暂无已注册的调试操作。'),
          );
        }
        actions.sort((a, b) {
          final g1 = a.group ?? '';
          final g2 = b.group ?? '';
          if (g1 != g2) return g1.compareTo(g2);
          return a.name.compareTo(b.name);
        });

        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return _buildActionTile(context, action);
          },
        );
      },
    );
  }

  Widget _buildActionTile(BuildContext context, DebugAction action) {
    final theme = Theme.of(context);
    final isRunning = _running && _runningId == action.id;
    final result = _results[action.id];

    return ListTile(
      title: Text(action.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.description != null && action.description!.isNotEmpty)
            Text(
              action.description!,
              style: theme.textTheme.bodySmall,
            ),
          if (action.group != null && action.group!.isNotEmpty)
            Text(
              '分组: ${action.group}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          // BUG FIX: 用内联文字反馈代替 SnackBar（面板在 MaterialApp 之上，
          // ScaffoldMessenger.maybeOf 返回 null，SnackBar 永远不会显示）。
          if (result != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                result.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: result.success ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: isRunning
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '执行',
              onPressed: () => _runAction(context, action),
            ),
    );
  }

  Future<void> _runAction(BuildContext context, DebugAction action) async {
    if (_running) return;
    setState(() {
      _running = true;
      _runningId = action.id;
      // 清除上次结果
      _results.remove(action.id);
    });

    _ActionResult result;
    try {
      await action.action();
      result = _ActionResult(
        message: '"${action.name}" 执行成功。',
        success: true,
      );
    } catch (e) {
      result = _ActionResult(
        message: '"${action.name}" 执行失败: $e',
        success: false,
      );
    }

    if (mounted) {
      setState(() {
        _running = false;
        _runningId = null;
        _results[action.id] = result;
      });
    }
  }
}

/// 单次 action 执行结果。
class _ActionResult {
  const _ActionResult({required this.message, required this.success});

  final String message;
  final bool success;
}
