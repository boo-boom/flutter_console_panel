## 0.0.1

- 初始版本发布
- 支持日志查看（Logs）：自动捕获 debugPrint 与 FlutterError，支持四级过滤与关键字搜索
- 支持网络抓包（Network）：兼容 Dio 拦截器与 http.Client 包装，自动脱敏敏感 Header
- 支持状态监控（State）：注册 ValueListenable 实时监听或异步快照按需刷新
- 支持性能指标（Performance）：基于帧时间回调实时展示 FPS 与平均帧耗时
- 支持自定义调试动作（Actions）：注册任意异步/同步动作一键执行
- 支持 SharedPreferences 查看与编辑
- 可拖拽悬浮球入口，仅 Debug 模式下显示
