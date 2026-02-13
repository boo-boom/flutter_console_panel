# Flutter Console Panel

> 轻量级应用内调试面板 -- 在 Flutter App 中集成可拖拽悬浮球入口，提供日志查看、网络抓包、状态监控、性能指标与自定义调试动作五大功能模块。

## 目录

- [特性一览](#特性一览)
- [快速开始](#快速开始)
- [模块详解](#模块详解)
  - [Logs -- 日志](#logs----日志)
  - [Network -- 网络抓包](#network----网络抓包)
  - [State -- 状态监控](#state----状态监控)
  - [Performance -- 性能指标](#performance----性能指标)
  - [Actions -- 自定义动作](#actions----自定义动作)
- [配置参考](#配置参考)
- [编程式控制](#编程式控制)
- [导出 API 速查](#导出-api-速查)
- [项目结构](#项目结构)
- [设计原则](#设计原则)

---

## 特性一览

| 模块 | 功能 | 关键能力 |
|------|------|---------|
| **Logs** | 日志采集与浏览 | 自动捕获 `debugPrint` 与 `FlutterError`；支持 debug / info / warning / error 四级过滤；支持关键字搜索；支持 tag 分类 |
| **Network** | 网络请求抓包 | 支持 Dio 拦截器 & http.Client 包装两种接入方式；展示请求/响应头与 body；自动脱敏敏感 header（如 authorization、cookie）；记录请求耗时与状态码 |
| **State** | 应用状态监控 | 注册 `ValueListenable` 实时监听；注册异步快照按需刷新；支持分组展示；值以格式化 JSON 呈现 |
| **Performance** | 性能指标 | 基于 `SchedulerBinding` 帧时间回调；实时估算 FPS 与平均帧耗时（ms） |
| **Actions** | 自定义调试动作 | 注册任意异步/同步动作；支持分组与描述；一键执行（如清缓存、切环境、重置状态） |

---

## 快速开始

### 1. 添加依赖

在应用的 `pubspec.yaml` 中添加本地路径依赖：

```yaml
dependencies:
  flutter_console_panel:
    path: packages/flutter_console_panel
```

### 2. 初始化面板

在 `main.dart` 中用 `DebugPanel.init` 包裹根 Widget：

```dart
import 'package:flutter_console_panel/flutter_console_panel.dart';

void main() {
  runApp(
    DebugPanel.init(
      child: const MyApp(),
      config: const DebugConfig(
        // 可选：自定义配置
        maxLogEntries: 2000,
        maxNetworkEntries: 500,
      ),
    ),
  );
}
```

> **默认行为**：仅在 Debug 模式下显示悬浮球与面板，Release / Profile 模式下自动隐藏，零性能开销。

### 3. 使用面板

1. 以 Debug 模式运行应用（`flutter run`）。
2. 屏幕上会出现一个可拖拽的悬浮按钮（虫子图标）。
3. 点击按钮打开底部调试面板，切换 Tab 浏览各功能模块。

---

## 模块详解

### Logs -- 日志

初始化后自动接管 `debugPrint` 和 `FlutterError.onError`，无需额外配置即可在面板中浏览应用日志。

**业务侧主动写日志**（推荐使用 `DebugLog` 便捷 API）：

```dart
import 'package:flutter_console_panel/flutter_console_panel.dart';

// 四个级别对应四个静态方法
DebugLog.d('用户点击了按钮', tag: 'UI');       // Debug
DebugLog.i('登录成功', tag: 'Auth');            // Info
DebugLog.w('Token 即将过期', tag: 'Auth');      // Warning
DebugLog.e(                                     // Error
  '请求失败',
  tag: 'Network',
  error: exception,
  stack: stackTrace,
);
```

也可直接使用底层 `LogsService`：

```dart
LogsService.instance.log(
  '自定义消息',
  level: LogLevel.info,
  tag: 'custom',
);

// 清空日志
LogsService.instance.clear();
```

---

### Network -- 网络抓包

支持两种主流 HTTP 客户端的无侵入接入。

**Dio 接入**：

```dart
import 'package:dio/dio.dart';
import 'package:flutter_console_panel/flutter_console_panel.dart';

final dio = Dio();
DebugPanel.attachDio(dio);  // 自动添加拦截器
```

**http.Client 接入**：

```dart
import 'package:http/http.dart' as http;
import 'package:flutter_console_panel/flutter_console_panel.dart';

final client = DebugPanel.wrapHttpClient(http.Client());
// 之后正常使用 client 即可，所有请求自动被记录
```

面板中展示的信息包括：
- 请求方法 & URL
- 状态码 & 耗时
- 请求/响应 Headers（敏感字段自动脱敏为 `***`）
- 请求/响应 Body

```dart
// 清空网络记录
NetworkService.instance.clear();
```

---

### State -- 状态监控

将应用中的关键状态注册到面板，方便实时查看和调试。

**注册可监听值**（实时响应变化）：

```dart
final userNotifier = ValueNotifier<User?>(null);

StateService.instance.registerValue(
  'user',               // 唯一 key
  userNotifier,
  description: '当前登录用户',
  group: 'auth',        // 分组名（可选）
);
```

**注册异步快照**（点击刷新时加载）：

```dart
StateService.instance.registerAsync(
  'env.api',
  () async => Env.apiConfig.toString(),
  description: '当前接口配置',
  group: 'env',
);
```

**手动更新已注册项的值**：

```dart
StateService.instance.updateManual('user', newUserData);
```

**取消注册**：

```dart
StateService.instance.unregister('user');
```

---

### Performance -- 性能指标

初始化时自动启动，基于 `SchedulerBinding.addTimingsCallback` 采集帧时间，在面板中实时展示：

- **FPS**：估算的每秒帧数
- **Avg Frame**：平均每帧耗时（毫秒）

也可编程控制：

```dart
// 手动启停
PerformanceService.instance.start();
PerformanceService.instance.stop();

// 监听指标变化
PerformanceService.instance.metrics.addListener(() {
  final m = PerformanceService.instance.metrics.value;
  print('FPS: ${m.fps.toStringAsFixed(1)}, Avg: ${m.averageFrameMs.toStringAsFixed(2)}ms');
});
```

---

### Actions -- 自定义动作

注册开发/测试阶段常用的调试操作，在面板中一键执行。

```dart
import 'package:flutter_console_panel/flutter_console_panel.dart';

// 注册动作
ActionsService.instance.registerAction(
  id: 'clear_cache',
  name: '清理本地缓存',
  group: 'storage',
  description: '清除 SharedPreferences 中的所有数据',
  action: () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  },
);

ActionsService.instance.registerAction(
  id: 'switch_env',
  name: '切换到测试环境',
  group: 'env',
  action: () async {
    Env.current = Env.staging;
  },
);

// 取消注册
ActionsService.instance.unregisterAction('clear_cache');
```

---

## 配置参考

通过 `DebugConfig` 可精细控制面板行为：

```dart
const config = DebugConfig(
  enabled: true,                    // 总开关，默认 kDebugMode
  showInProfileMode: false,         // 是否在 Profile 构建下显示
  showInReleaseMode: false,         // 是否在 Release 构建下显示
  maxLogEntries: 1000,              // 内存中保留的日志条数上限
  maxNetworkEntries: 300,           // 内存中保留的网络请求条数上限
  maskSensitiveHeaders: [           // 需要脱敏的请求头 key
    'authorization',
    'cookie',
    'set-cookie',
  ],
  maskSensitiveKeys: [              // 需要脱敏的 JSON 字段名
    'password',
    'token',
    'accessToken',
    'refreshToken',
  ],
);
```

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `enabled` | `bool?` | `kDebugMode` | 总开关；`null` 时跟随编译模式 |
| `showInProfileMode` | `bool` | `false` | Profile 模式是否显示面板 |
| `showInReleaseMode` | `bool` | `false` | Release 模式是否显示面板 |
| `maxLogEntries` | `int` | `1000` | 日志条数上限，超出后丢弃最早记录 |
| `maxNetworkEntries` | `int` | `300` | 网络记录条数上限 |
| `maskSensitiveHeaders` | `List<String>` | `['authorization', 'cookie', 'set-cookie']` | 在 UI 中脱敏的 HTTP Header Key |
| `maskSensitiveKeys` | `List<String>` | `['password', 'token', 'accessToken', 'refreshToken']` | 在 UI 中脱敏的 JSON 字段名 |

---

## 编程式控制

除了通过悬浮球交互外，也可以用代码控制面板的显示/隐藏：

```dart
// 打开面板
DebugPanel.showPanel();

// 关闭面板
DebugPanel.hidePanel();

// 切换显示/隐藏
DebugPanel.togglePanel();

// 访问底层控制器
final controller = DebugPanel.instance;
controller.panelVisible; // ValueListenable<bool>，可监听面板状态
controller.isEnabled;    // 当前构建模式下是否启用
```

---

## 导出 API 速查

从 `package:flutter_console_panel/flutter_console_panel.dart` 导入可使用以下类型：

| 类别 | 导出类型 |
|------|---------|
| **核心** | `DebugPanel`、`DebugConfig` |
| **日志** | `LogsService`、`DebugLog`、`LogEntry`、`LogLevel` |
| **网络** | `NetworkService`、`NetworkEntry` |
| **状态** | `StateService`、`DebugStateEntry`、`DebugStateSourceType` |
| **性能** | `PerformanceService`、`PerformanceMetrics` |
| **动作** | `ActionsService`、`DebugAction` |

---

## 项目结构

```
flutter_console_panel/
├── lib/
│   ├── flutter_console_panel.dart        # 统一导出入口
│   └── src/
│       ├── core/
│       │   ├── debug_config.dart        # 全局配置
│       │   ├── debug_panel.dart         # 对外 API & 控制器
│       │   └── debug_overlay_entry.dart # 悬浮球 & Overlay 根组件
│       ├── ui/
│       │   └── debug_panel_shell.dart   # 面板 Shell（Tab 容器）
│       └── modules/
│           ├── logs/
│           │   ├── logs_service.dart     # 日志采集服务
│           │   └── logs_tab.dart         # 日志 Tab UI
│           ├── network/
│           │   ├── network_service.dart  # 网络抓包服务
│           │   └── network_tab.dart      # 网络 Tab UI
│           ├── state/
│           │   ├── state_service.dart    # 状态注册服务
│           │   └── state_tab.dart        # 状态 Tab UI
│           ├── performance/
│           │   ├── performance_service.dart  # 性能监控服务
│           │   └── performance_tab.dart      # 性能 Tab UI
│           └── actions/
│               ├── actions_service.dart  # 自定义动作注册
│               └── actions_tab.dart      # 动作 Tab UI
└── pubspec.yaml
```

---

## 特色

- **零侵入**：所有模块内部异常均被捕获吞掉，绝不影响宿主应用的正常运行。
- **按需接入**：只有 `DebugPanel.init` 是必须的，网络抓包、状态注册、自定义动作均为可选集成。
- **默认安全**：Release 模式下默认不启用，避免调试代码误上线；敏感信息（token、密码等）自动脱敏。
- **轻量高效**：内存中日志与网络记录有条数上限，自动淘汰旧数据，不会无限增长。
- **单例模式**：各 Service 均为单例，全局统一管理，应用内任意位置均可调用。

---

## 作者

**boom**

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
