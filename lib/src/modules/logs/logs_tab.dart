import 'package:flutter/material.dart';

import 'logs_service.dart';

/// 日志 Tab：展示已采集日志，支持关键字搜索。
class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  final TextEditingController _searchController = TextEditingController();

  /// 当前选中查看详情的日志条目，null 表示列表模式。
  LogEntry? _selectedEntry;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 详情模式：展示选中日志的完整信息。
    final selected = _selectedEntry;
    if (selected != null) {
      return _buildDetailView(context, selected);
    }

    // 列表模式：工具栏 + 日志列表。
    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<LogEntry>>(
            valueListenable: LogsService.instance.entries,
            builder: (context, entries, _) {
              final filtered = _applyFilters(entries);
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('暂无日志记录。'),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return _buildLogTile(context, entry);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '搜索日志...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              style: theme.textTheme.bodySmall,
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          IconButton(
            tooltip: '清除日志',
            icon: const Icon(Icons.delete_outline),
            onPressed: LogsService.instance.clear,
          ),
        ],
      ),
    );
  }

  List<LogEntry> _applyFilters(List<LogEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return entries;
    return entries.where((e) {
      final msg = e.message.toLowerCase();
      final tag = e.tag?.toLowerCase() ?? '';
      return msg.contains(query) || tag.contains(query);
    }).toList();
  }

  Widget _buildLogTile(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final color = _levelColor(entry.level, theme);
    final timeStr = _formatTime(entry.timestamp);

    final subtitle = StringBuffer()
      ..write(timeStr)
      ..write('  ')
      ..write(entry.level.label);
    if (entry.tag != null && entry.tag!.isNotEmpty) {
      subtitle.write('  [${entry.tag}]');
    }

    return InkWell(
      onTap: () => setState(() => _selectedEntry = entry),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: ListTile(
          dense: true,
          title: Text(
            entry.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          subtitle: Text(
            subtitle.toString(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withAlpha(179),
            ),
          ),
          trailing: entry.level == LogLevel.error || entry.error != null
              ? const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 18,
                )
              : null,
        ),
      ),
    );
  }

  Color _levelColor(LogLevel level, ThemeData theme) {
    switch (level) {
      case LogLevel.debug:
        return theme.colorScheme.primary.withAlpha(179);
      case LogLevel.info:
        return Colors.blueAccent;
      case LogLevel.warning:
        return Colors.orangeAccent;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// 内联详情视图（不依赖 Navigator，避免在 Overlay 中使用 showModalBottomSheet 崩溃）。
  Widget _buildDetailView(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final buffer = StringBuffer()
      ..writeln(entry.message)
      ..writeln()
      ..writeln('时间: ${entry.timestamp.toIso8601String()}')
      ..writeln('级别: ${entry.level.label}');
    if (entry.tag != null) buffer.writeln('标签: ${entry.tag}');
    if (entry.error != null) buffer.writeln('错误: ${entry.error}');
    if (entry.stackTrace != null) {
      buffer
        ..writeln()
        ..writeln('堆栈跟踪:')
        ..writeln(entry.stackTrace);
    }

    return Column(
      children: [
        // 顶部栏：返回按钮 + 标题
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                tooltip: '返回',
                onPressed: () => setState(() => _selectedEntry = null),
              ),
              const SizedBox(width: 4),
              Text(
                '日志详情',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              // 日志级别标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _levelColor(entry.level, theme),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.level.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: SelectableText(
                  buffer.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
