import 'package:flutter/material.dart';

import 'state_service.dart';

/// 状态 Tab：展示已注册的应用状态项及其 JSON 快照，支持搜索与异步刷新。
class StateTab extends StatefulWidget {
  const StateTab({super.key});

  @override
  State<StateTab> createState() => _StateTabState();
}

class _StateTabState extends State<StateTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StateService.instance,
      builder: (context, _) {
        final entries = StateService.instance.entries.values.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final filtered = entries.where((e) {
          if (_search.isEmpty) return true;
          final q = _search.toLowerCase();
          return e.key.toLowerCase().contains(q) ||
              (e.description ?? '').toLowerCase().contains(q) ||
              (e.group ?? '').toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            _buildToolbar(),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('暂无已注册的状态。'),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final entry = filtered[index];
                        return _buildEntryTile(context, entry);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: TextField(
        decoration: const InputDecoration(
          isDense: true,
          hintText: '搜索状态键 / 描述 / 分组...',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search, size: 18),
        ),
        onChanged: (value) {
          setState(() {
            _search = value.trim();
          });
        },
      ),
    );
  }

  Widget _buildEntryTile(BuildContext context, DebugStateEntry entry) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      title: Text(
        entry.key,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entry.description != null && entry.description!.isNotEmpty)
            Text(
              entry.description!,
              style: theme.textTheme.bodySmall,
            ),
          if (entry.group != null && entry.group!.isNotEmpty)
            Text(
              '分组: ${entry.group}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
      trailing: entry.sourceType == DebugStateSourceType.asyncSnapshot
          ? IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: () => StateService.instance.reloadAsync(entry.key),
            )
          : null,
      children: [
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              StateService.instance.prettyJson(entry.value),
              style:
                  theme.textTheme.bodySmall ??
                  const TextStyle(fontSize: 12, height: 1.3),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
