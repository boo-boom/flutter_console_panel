import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'shared_prefs_service.dart';

/// 存储 Tab：展示 SharedPreferences 全部键值对，支持搜索、新增、编辑、删除。
class SharedPrefsTab extends StatefulWidget {
  const SharedPrefsTab({super.key});

  @override
  State<SharedPrefsTab> createState() => _SharedPrefsTabState();
}

class _SharedPrefsTabState extends State<SharedPrefsTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SharedPrefsService.instance,
      builder: (context, _) {
        final service = SharedPrefsService.instance;
        final entries = service.entries.where((e) {
          if (_search.isEmpty) return true;
          final q = _search.toLowerCase();
          return e.key.toLowerCase().contains(q) ||
              service.formatValue(e).toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            _buildToolbar(context),
            if (service.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                color: Colors.red.withAlpha(30),
                child: Text(
                  service.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const Divider(height: 1),
            Expanded(child: _buildBody(context, service, entries)),
          ],
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final service = SharedPrefsService.instance;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: '搜索键名 / 值...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (value) {
                setState(() {
                  _search = value.trim();
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => service.loadAll(),
          ),
          IconButton(
            tooltip: '新增',
            icon: const Icon(Icons.add, size: 20),
            onPressed: () => _showAddDialog(context),
          ),
          IconButton(
            tooltip: '清空全部',
            icon: const Icon(Icons.delete_sweep, size: 20),
            onPressed: () => _showClearAllDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SharedPrefsService service,
    List<SharedPrefsEntry> entries,
  ) {
    if (service.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('暂无存储数据'),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('点击加载'),
              onPressed: () => service.loadAll(),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildEntryTile(context, entry);
      },
    );
  }

  Widget _buildEntryTile(BuildContext context, SharedPrefsEntry entry) {
    final theme = Theme.of(context);
    final service = SharedPrefsService.instance;
    final valueStr = service.formatValue(entry);

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      leading: _buildTypeBadge(entry.type),
      title: Text(
        entry.key,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        valueStr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      children: [
        SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              valueStr,
              style:
                  theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ) ??
                  const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.4,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 14),
              label: const Text('复制'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: valueStr));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制到剪贴板'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('编辑'),
              onPressed: () => _showEditDialog(context, entry),
            ),
            TextButton.icon(
              icon: Icon(Icons.delete, size: 14, color: Colors.red[400]),
              label: Text('删除', style: TextStyle(color: Colors.red[400])),
              onPressed: () => _showDeleteDialog(context, entry),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeBadge(SharedPrefsValueType type) {
    Color color;
    switch (type) {
      case SharedPrefsValueType.string:
        color = Colors.blue;
      case SharedPrefsValueType.int:
        color = Colors.green;
      case SharedPrefsValueType.double:
        color = Colors.orange;
      case SharedPrefsValueType.bool:
        color = Colors.purple;
      case SharedPrefsValueType.stringList:
        color = Colors.teal;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        type.label,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─────────────────────── 新增对话框 ───────────────────────

  Future<void> _showAddDialog(BuildContext context) async {
    final keyController = TextEditingController();
    final valueController = TextEditingController();
    var selectedType = SharedPrefsValueType.string;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('新增键值对'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: keyController,
                      decoration: const InputDecoration(
                        labelText: '键名 (Key)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SharedPrefsValueType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: SharedPrefsValueType.values.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueController,
                      maxLines:
                          selectedType == SharedPrefsValueType.stringList
                              ? 5
                              : 1,
                      decoration: InputDecoration(
                        labelText: '值 (Value)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        hintText:
                            selectedType == SharedPrefsValueType.stringList
                                ? '每行一个元素'
                                : selectedType == SharedPrefsValueType.bool
                                ? 'true 或 false'
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && keyController.text.trim().isNotEmpty) {
      await SharedPrefsService.instance.setValue(
        keyController.text.trim(),
        valueController.text,
        selectedType,
      );
    }

    keyController.dispose();
    valueController.dispose();
  }

  // ─────────────────────── 编辑对话框 ───────────────────────

  Future<void> _showEditDialog(
    BuildContext context,
    SharedPrefsEntry entry,
  ) async {
    final service = SharedPrefsService.instance;
    final valueController = TextEditingController(
      text: service.formatValue(entry),
    );
    var selectedType = entry.type;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('编辑: ${entry.key}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<SharedPrefsValueType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: '类型',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: SharedPrefsValueType.values.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedType = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueController,
                      maxLines:
                          selectedType == SharedPrefsValueType.stringList
                              ? 5
                              : 1,
                      decoration: InputDecoration(
                        labelText: '值 (Value)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        hintText:
                            selectedType == SharedPrefsValueType.stringList
                                ? '每行一个元素'
                                : selectedType == SharedPrefsValueType.bool
                                ? 'true 或 false'
                                : null,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      await service.setValue(entry.key, valueController.text, selectedType);
    }

    valueController.dispose();
  }

  // ─────────────────────── 删除确认对话框 ───────────────────────

  Future<void> _showDeleteDialog(
    BuildContext context,
    SharedPrefsEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除键 "${entry.key}" 吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await SharedPrefsService.instance.remove(entry.key);
    }
  }

  // ─────────────────────── 清空全部确认对话框 ───────────────────────

  Future<void> _showClearAllDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('确认清空'),
          content: const Text('确定要清空所有 SharedPreferences 数据吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await SharedPrefsService.instance.clearAll();
    }
  }
}
