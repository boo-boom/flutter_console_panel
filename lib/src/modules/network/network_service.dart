import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/debug_config.dart';

/// 单条网络请求记录，供调试面板 Network Tab 展示。
class NetworkEntry {
  NetworkEntry({
    required this.id,
    required this.method,
    required this.url,
    required this.timestamp,
    this.statusCode,
    this.duration,
    this.requestHeaders,
    this.responseHeaders,
    this.requestBody,
    this.responseBody,
    this.error,
  });

  final int id;
  final String method;
  final String url;
  final DateTime timestamp;
  final int? statusCode;
  final Duration? duration;
  final Map<String, dynamic>? requestHeaders;
  final Map<String, dynamic>? responseHeaders;
  final Object? requestBody;
  final Object? responseBody;
  final Object? error;
}

/// 网络抓包服务：通过 Dio 拦截器或包装 http.Client 记录请求/响应。
class NetworkService {
  NetworkService._internal();

  static final NetworkService instance = NetworkService._internal();

  final ValueNotifier<List<NetworkEntry>> _entriesNotifier = ValueNotifier<List<NetworkEntry>>(<NetworkEntry>[]);

  ValueListenable<List<NetworkEntry>> get entries => _entriesNotifier;

  int _maxEntries = 300;
  DebugConfig _config = const DebugConfig();
  int _nextId = 1;

  /// 应用配置（条数上限、敏感头脱敏等）。
  void applyConfig(DebugConfig config) {
    _config = config;
    _maxEntries = config.maxNetworkEntries;
  }

  /// 追加一条记录并维持条数上限。
  void _addEntry(NetworkEntry entry) {
    final List<NetworkEntry> current = List<NetworkEntry>.from(
      _entriesNotifier.value,
    )..add(entry);
    if (current.length > _maxEntries) {
      current.removeRange(0, current.length - _maxEntries);
    }
    _entriesNotifier.value = current;
  }

  /// 对配置中的敏感请求头进行脱敏（替换为 ***）。
  Map<String, dynamic>? _maskHeaders(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    final lowerKeys = _config.maskSensitiveHeaders.map((k) => k.toLowerCase());
    return headers.map((key, value) {
      if (lowerKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  /// 为 Dio 实例添加拦截器，自动记录请求与响应到内存。
  void attachDio(Dio dio, {DebugConfig? config}) {
    if (config != null) {
      applyConfig(config);
    }

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            options.extra['__debug_start_time'] = DateTime.now(); // 用于计算耗时
          } catch (_) {
            // 调试模块内部错误不影响请求本身。
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          try {
            _recordDioResponse(response);
          } catch (_) {
            // 忽略所有抓包过程中的异常。
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          try {
            _recordDioError(e);
          } catch (_) {
            // 忽略所有抓包过程中的异常。
          }
          return handler.next(e);
        },
      ),
    );
  }

  /// 记录一次 Dio 成功响应。
  void _recordDioResponse(Response response) {
    final options = response.requestOptions;
    final startTime = options.extra['__debug_start_time'] as DateTime?;
    final endTime = DateTime.now();
    final duration = startTime != null ? endTime.difference(startTime) : null;

    final entry = NetworkEntry(
      id: _nextId++,
      method: options.method,
      url: options.uri.toString(),
      timestamp: startTime ?? endTime,
      statusCode: response.statusCode,
      duration: duration,
      requestHeaders: _maskHeaders(options.headers),
      responseHeaders: _maskHeaders(response.headers.map),
      requestBody: options.data,
      responseBody: response.data,
    );
    _addEntry(entry);
  }

  /// 记录一次 Dio 错误（含部分响应信息）。
  void _recordDioError(DioException e) {
    final options = e.requestOptions;
    final startTime = options.extra['__debug_start_time'] as DateTime?;
    final endTime = DateTime.now();
    final duration = startTime != null ? endTime.difference(startTime) : null;

    final statusCode = e.response?.statusCode;
    final entry = NetworkEntry(
      id: _nextId++,
      method: options.method,
      url: options.uri.toString(),
      timestamp: startTime ?? endTime,
      statusCode: statusCode,
      duration: duration,
      requestHeaders: _maskHeaders(options.headers),
      responseHeaders: _maskHeaders(e.response?.headers.map),
      requestBody: options.data,
      responseBody: e.response?.data,
      error: e,
    );
    _addEntry(entry);
  }

  /// 清空当前所有网络请求记录。
  void clear() {
    _entriesNotifier.value = const <NetworkEntry>[];
  }

  /// 包装 http.Client，使通过该 client 发出的请求被记录（仅记录元数据，不缓冲 body）。
  http.Client wrapHttpClient(http.Client inner, {DebugConfig? config}) {
    if (config != null) {
      applyConfig(config);
    }
    return _DebugHttpClient(inner, this);
  }
}

/// 包装后的 http.Client，在 send 时记录请求信息。
class _DebugHttpClient extends http.BaseClient {
  _DebugHttpClient(this._inner, this._service);

  final http.Client _inner;
  final NetworkService _service;

  /// 关闭内部 http.Client，释放资源。
  @override
  void close() {
    _inner.close();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();
    http.StreamedResponse? response;
    Object? error;

    try {
      response = await _inner.send(request);
      return response;
    } catch (e) {
      error = e;
      rethrow;
    } finally {
      try {
        final endTime = DateTime.now();
        final url = request.url.toString();
        final method = request.method;

        // 此处仅记录请求头与元数据，不缓冲 body 流。
        final entry = NetworkEntry(
          id: _service._nextId++,
          method: method,
          url: url,
          timestamp: startTime,
          statusCode: error == null ? response?.statusCode : null,
          duration: endTime.difference(startTime),
          requestHeaders: _service._maskHeaders(request.headers),
          responseHeaders: error == null && response != null ? _service._maskHeaders(response.headers) : null,
          error: error,
        );
        _service._addEntry(entry);
      } catch (_) {
        // 记录失败也不会改变 http.Client 的原始行为。
      }
    }
  }
}
