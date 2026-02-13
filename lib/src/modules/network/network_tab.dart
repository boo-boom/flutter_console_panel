import 'package:flutter/material.dart';

import 'network_service.dart';

/// 网络 Tab：列表展示已抓取的 HTTP 请求，支持按方法/状态/URL 筛选，点击查看详情。
class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key});

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _methodFilter;
  int? _statusFilter; // 按百位分组：2xx、4xx 等

  /// 当前选中查看详情的网络条目，null 表示列表模式。
  NetworkEntry? _selectedEntry;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 详情模式：展示选中请求的完整信息。
    final selected = _selectedEntry;
    if (selected != null) {
      return _buildDetailView(context, selected);
    }

    // 列表模式：工具栏 + 请求列表。
    return Column(
      children: [
        _buildToolbar(context),
        const Divider(height: 1),
        Expanded(
          child: ValueListenableBuilder<List<NetworkEntry>>(
            valueListenable: NetworkService.instance.entries,
            builder: (context, entries, _) {
              final filtered = _applyFilters(entries);
              if (filtered.isEmpty) {
                return const Center(
                  child: Text('暂无网络请求记录。'),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  return _buildEntryTile(context, entry);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          DropdownButton<String?>(
            value: _methodFilter,
            hint: const Text('方法'),
            onChanged: (value) {
              setState(() {
                _methodFilter = value;
              });
            },
            items: const [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('全部'),
              ),
              DropdownMenuItem<String?>(
                value: 'GET',
                child: Text('GET'),
              ),
              DropdownMenuItem<String?>(
                value: 'POST',
                child: Text('POST'),
              ),
              DropdownMenuItem<String?>(
                value: 'PUT',
                child: Text('PUT'),
              ),
              DropdownMenuItem<String?>(
                value: 'DELETE',
                child: Text('DELETE'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          DropdownButton<int?>(
            value: _statusFilter,
            hint: const Text('状态'),
            onChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
            items: const [
              DropdownMenuItem<int?>(
                value: null,
                child: Text('全部'),
              ),
              DropdownMenuItem<int?>(
                value: 200,
                child: Text('2xx'),
              ),
              DropdownMenuItem<int?>(
                value: 300,
                child: Text('3xx'),
              ),
              DropdownMenuItem<int?>(
                value: 400,
                child: Text('4xx'),
              ),
              DropdownMenuItem<int?>(
                value: 500,
                child: Text('5xx'),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                isDense: true,
                hintText: '搜索 URL...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          IconButton(
            tooltip: '清除请求',
            icon: const Icon(Icons.delete_outline),
            onPressed: NetworkService.instance.clear,
          ),
        ],
      ),
    );
  }

  List<NetworkEntry> _applyFilters(List<NetworkEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();
    return entries.where((e) {
      if (_methodFilter != null && e.method.toUpperCase() != _methodFilter) {
        return false;
      }
      // BUG FIX: 当选择了状态码筛选时，statusCode 为 null 的条目应被过滤掉。
      if (_statusFilter != null) {
        if (e.statusCode == null) return false;
        final base = _statusFilter!;
        final code = e.statusCode!;
        if (code < base || code >= base + 100) {
          return false;
        }
      }
      if (query.isNotEmpty && !e.url.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget _buildEntryTile(BuildContext context, NetworkEntry entry) {
    final theme = Theme.of(context);
    final status = entry.statusCode;
    final durationMs = entry.duration?.inMilliseconds;
    final statusColor = _statusColor(status, theme);

    return ListTile(
      dense: true,
      onTap: () => setState(() => _selectedEntry = entry),
      title: Text(
        entry.url,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      subtitle: Text(
        '${entry.method}  '
        '${status ?? '-'}  '
        '${durationMs != null ? '${durationMs}ms' : ''}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.textTheme.bodySmall?.color?.withAlpha(179),
        ),
      ),
      // BUG FIX: 使用固定高度的 Container 代替 height: double.infinity，
      // 避免 ListTile 内部 unconstrained 布局错误。
      leading: Container(
        width: 6,
        height: 40,
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      trailing: status == null || status >= 400 ? const Icon(Icons.error_outline, size: 18, color: Colors.redAccent) : null,
    );
  }

  Color _statusColor(int? status, ThemeData theme) {
    if (status == null) return Colors.grey;
    if (status >= 200 && status < 300) return Colors.green;
    if (status >= 300 && status < 400) return Colors.blue;
    if (status >= 400 && status < 500) return Colors.orange;
    return Colors.redAccent;
  }

  /// 内联详情视图（不依赖 Navigator，避免在 Overlay 中使用 showModalBottomSheet 崩溃）。
  Widget _buildDetailView(BuildContext context, NetworkEntry entry) {
    final theme = Theme.of(context);
    final defaultTextStyle = theme.textTheme.bodySmall ?? const TextStyle(fontSize: 12, color: Colors.black87);

    return Column(
      children: [
        // 顶部栏：返回按钮 + URL
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
              Expanded(
                child: Text(
                  entry.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              // 状态码标签
              if (entry.statusCode != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(entry.statusCode, theme),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${entry.statusCode}',
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
            child: DefaultTextStyle(
              style: defaultTextStyle,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.url,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('方法: ${entry.method}'),
                    Text('状态: ${entry.statusCode ?? '-'}'),
                    if (entry.duration != null) Text('耗时: ${entry.duration!.inMilliseconds} 毫秒'),
                    const SizedBox(height: 12),
                    if (entry.requestHeaders != null) ...[
                      const Text(
                        '请求头：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(entry.requestHeaders.toString()),
                      const SizedBox(height: 8),
                    ],
                    if (entry.requestBody != null) ...[
                      const Text(
                        '请求体：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(entry.requestBody.toString()),
                      const SizedBox(height: 8),
                    ],
                    if (entry.responseHeaders != null) ...[
                      const Text(
                        '响应头：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(entry.responseHeaders.toString()),
                      const SizedBox(height: 8),
                    ],
                    if (entry.responseBody != null) ...[
                      const Text(
                        '响应体：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SelectableText(
                        entry.responseBody.toString(),
                        maxLines: 200,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (entry.error != null) ...[
                      const Text(
                        '错误：',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      SelectableText(entry.error.toString()),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
