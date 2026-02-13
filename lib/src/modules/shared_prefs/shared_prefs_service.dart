import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences 中值的类型枚举。
enum SharedPrefsValueType {
  string('String'),
  int('int'),
  double('double'),
  bool('bool'),
  stringList('List<String>');

  const SharedPrefsValueType(this.label);

  final String label;
}

/// 单条 SharedPreferences 键值对条目。
class SharedPrefsEntry {
  SharedPrefsEntry({
    required this.key,
    required this.value,
    required this.type,
  });

  final String key;
  Object? value;
  SharedPrefsValueType type;
}

/// SharedPreferences 调试服务：加载、展示、增删改查本地存储内容。
class SharedPrefsService extends ChangeNotifier {
  SharedPrefsService._internal();

  static final SharedPrefsService instance = SharedPrefsService._internal();

  List<SharedPrefsEntry> _entries = <SharedPrefsEntry>[];
  bool _isLoading = false;
  String? _error;

  /// 当前所有条目（只读副本）。
  List<SharedPrefsEntry> get entries => List.unmodifiable(_entries);

  /// 是否正在加载中。
  bool get isLoading => _isLoading;

  /// 最近一次操作的错误信息。
  String? get error => _error;

  /// 加载所有 SharedPreferences 键值对。
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final keys = prefs.getKeys().toList()..sort();

      final list = <SharedPrefsEntry>[];
      for (final key in keys) {
        final entry = _readEntry(prefs, key);
        if (entry != null) {
          list.add(entry);
        }
      }
      _entries = list;
    } catch (e) {
      _error = '加载失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 添加或更新一个键值对。
  Future<bool> setValue(
    String key,
    String rawValue,
    SharedPrefsValueType type,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (type) {
        case SharedPrefsValueType.string:
          await prefs.setString(key, rawValue);
        case SharedPrefsValueType.int:
          final v = int.parse(rawValue.trim());
          await prefs.setInt(key, v);
        case SharedPrefsValueType.double:
          final v = double.parse(rawValue.trim());
          await prefs.setDouble(key, v);
        case SharedPrefsValueType.bool:
          final v = rawValue.trim().toLowerCase();
          if (v != 'true' && v != 'false') {
            _error = '布尔值只能是 true 或 false';
            notifyListeners();
            return false;
          }
          await prefs.setBool(key, v == 'true');
        case SharedPrefsValueType.stringList:
          final v =
              rawValue
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
          await prefs.setStringList(key, v);
      }
      _error = null;
      await loadAll();
      return true;
    } catch (e) {
      _error = '保存失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 删除指定键。
  Future<bool> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      _error = null;
      await loadAll();
      return true;
    } catch (e) {
      _error = '删除失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 清空所有 SharedPreferences。
  Future<bool> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _error = null;
      await loadAll();
      return true;
    } catch (e) {
      _error = '清空失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 从 SharedPreferences 实例中读取单条条目，自动推断类型。
  SharedPrefsEntry? _readEntry(SharedPreferences prefs, String key) {
    try {
      final raw = prefs.get(key);
      if (raw == null) return null;

      SharedPrefsValueType type;
      if (raw is String) {
        type = SharedPrefsValueType.string;
      } else if (raw is int) {
        type = SharedPrefsValueType.int;
      } else if (raw is double) {
        type = SharedPrefsValueType.double;
      } else if (raw is bool) {
        type = SharedPrefsValueType.bool;
      } else if (raw is List) {
        type = SharedPrefsValueType.stringList;
      } else {
        type = SharedPrefsValueType.string;
      }

      return SharedPrefsEntry(key: key, value: raw, type: type);
    } catch (_) {
      return null;
    }
  }

  /// 将值格式化为可读字符串。
  String formatValue(SharedPrefsEntry entry) {
    if (entry.value == null) return 'null';
    if (entry.type == SharedPrefsValueType.stringList) {
      final list = entry.value as List;
      if (list.isEmpty) return '[]';
      return list.map((e) => e.toString()).join('\n');
    }
    return entry.value.toString();
  }
}
