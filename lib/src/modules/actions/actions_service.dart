import 'dart:async';

import 'package:flutter/foundation.dart';

/// 一条自定义调试动作（如清缓存、切换环境）。
class DebugAction {
  DebugAction({
    required this.id,
    required this.name,
    required this.action,
    this.group,
    this.description,
  });

  final String id;
  final String name;
  final String? group;
  final String? description;
  final FutureOr<void> Function() action;
}

/// 自定义调试动作注册表，供 Actions Tab 展示与执行。
class ActionsService extends ChangeNotifier {
  ActionsService._internal();

  static final ActionsService instance = ActionsService._internal();

  final Map<String, DebugAction> _actions = <String, DebugAction>{};

  List<DebugAction> get actions => _actions.values.toList();

  /// 注册一个调试动作，可在面板中点击执行。
  void registerAction({
    required String id,
    required String name,
    required FutureOr<void> Function() action,
    String? group,
    String? description,
  }) {
    _actions[id] = DebugAction(
      id: id,
      name: name,
      group: group,
      description: description,
      action: action,
    );
    notifyListeners();
  }

  /// 取消注册指定 id 的动作。
  void unregisterAction(String id) {
    _actions.remove(id);
    notifyListeners();
  }
}
