import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 单条已注册的状态项。
class DebugStateEntry {
  DebugStateEntry({
    required this.key,
    this.description,
    this.group,
    this.readOnly = true,
    this.sourceType = DebugStateSourceType.valueListenable,
    this.value,
    this.asyncLoader,
  });

  final String key;
  final String? description;
  final String? group;
  final bool readOnly;
  final DebugStateSourceType sourceType;

  /// 当前快照值，尽量为可 JSON 序列化的类型。
  Object? value;

  /// 异步加载函数，仅 registerAsync 时使用。
  final Future<Object?> Function()? asyncLoader;
}

/// 状态来源类型：可监听值、异步快照、手动更新。
enum DebugStateSourceType {
  valueListenable,
  asyncSnapshot,
  manual,
}

/// 状态注册服务：将应用内状态注册到调试面板 State Tab 中展示。
class StateService extends ChangeNotifier {
  StateService._internal();

  static final StateService instance = StateService._internal();

  final Map<String, DebugStateEntry> _entries = <String, DebugStateEntry>{};
  final Map<String, VoidCallback> _valueListenableDisposers =
      <String, VoidCallback>{};

  Map<String, DebugStateEntry> get entries => Map.unmodifiable(_entries);

  /// 注册一个 ValueListenable，面板会监听其变化并刷新显示。
  void registerValue(
    String key,
    ValueListenable<dynamic> listenable, {
    String? description,
    String? group,
  }) {
    _disposeValueListenable(key);

    final entry = DebugStateEntry(
      key: key,
      description: description,
      group: group,
      sourceType: DebugStateSourceType.valueListenable,
      value: _safeJsonSnapshot(listenable.value),
    );
    _entries[key] = entry;
    notifyListeners();

    void listener() {
      entry.value = _safeJsonSnapshot(listenable.value);
      notifyListeners();
    }

    listenable.addListener(listener);
    _valueListenableDisposers[key] = () => listenable.removeListener(listener);
  }

  /// 注册一个异步状态项，在面板中点击刷新时再加载当前值。
  void registerAsync(
    String key,
    Future<Object?> Function() loader, {
    String? description,
    String? group,
  }) {
    _disposeValueListenable(key);

    final entry = DebugStateEntry(
      key: key,
      description: description,
      group: group,
      readOnly: true,
      sourceType: DebugStateSourceType.asyncSnapshot,
      value: '点击刷新加载',
      asyncLoader: loader,
    );
    _entries[key] = entry;
    notifyListeners();
  }

  /// 手动更新已注册项的值（简单场景用）。
  void updateManual(String key, Object? value) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.value = _safeJsonSnapshot(value);
    notifyListeners();
  }

  /// 取消注册指定 key 的状态项。
  void unregister(String key) {
    _disposeValueListenable(key);
    _entries.remove(key);
    notifyListeners();
  }

  /// 触发某条异步状态项的重新加载。
  Future<void> reloadAsync(String key) async {
    final entry = _entries[key];
    if (entry == null || entry.asyncLoader == null) return;

    entry.value = '加载中...';
    notifyListeners();
    try {
      final value = await entry.asyncLoader!.call();
      entry.value = _safeJsonSnapshot(value);
    } catch (e) {
      entry.value = '错误: $e';
    }
    notifyListeners();
  }

  void _disposeValueListenable(String key) {
    final disposer = _valueListenableDisposers.remove(key);
    disposer?.call();
  }

  /// 将值格式化为易读的 JSON 字符串（用于 State Tab 展示）。
  String prettyJson(Object? value) {
    try {
      if (value == null) return 'null';
      if (value is String) return value;
      final encoded = jsonEncode(value);
      const decoder = JsonDecoder();
      const encoder = JsonEncoder.withIndent('  ');
      final dynamic decoded = decoder.convert(encoded);
      return encoder.convert(decoded);
    } catch (_) {
      return value.toString();
    }
  }

  /// 取值的简单快照，具体序列化在 prettyJson 中再做。
  Object? _safeJsonSnapshot(Object? value) {
    return value;
  }
}
