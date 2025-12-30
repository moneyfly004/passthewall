import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class DioHttpClient with InfraLogger {
  final Map<String, Dio> _dio = {};
  String? _accessToken;
  
  DioHttpClient({
    required Duration timeout,
    required String userAgent,
    required bool debug,
  }) {
    for (final mode in ["proxy", "direct", "both"]) {
      _dio[mode] = Dio(
        BaseOptions(
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {"User-Agent": userAgent},
        ),
      );
      _dio[mode]!.interceptors.add(
            RetryInterceptor(
              dio: _dio[mode]!,
              retryDelays: [
                const Duration(seconds: 1),
                if (mode != "proxy") ...[
                  const Duration(seconds: 2),
                  const Duration(seconds: 3),
                ],
              ],
            ),
          );

      _dio[mode]!.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (url) {
            if (mode == "proxy") {
              return "PROXY localhost:$port";
            } else if (mode == "direct") {
              return "DIRECT";
            } else {
              return "PROXY localhost:$port; DIRECT";
            }
          };
          return client;
        },
      );
    }

    if (debug) {
      // _dio.interceptors.add(LoggyDioInterceptor(requestHeader: true));
    }
  }

  int port = 0;
  // bool isPortOpen(String host, int port, {Duration timeout = const Duration(milliseconds: 200)}) async{
  //   try {
  //     Socket.connect(host, port, timeout: timeout).then((socket) {
  //       socket.destroy();
  //     });
  //     return true;
  //   } on SocketException catch (_) {
  //     return false;
  //   } catch (_) {
  //     return false;
  //   }
  // }
  Future<bool> isPortOpen(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void setProxyPort(int port) {
    this.port = port;
    loggy.debug("setting proxy port: [$port]");
  }

  void setAccessToken(String? token) {
    _accessToken = token;
    for (final dio in _dio.values) {
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      } else {
        dio.options.headers.remove('Authorization');
      }
    }
  }

  void clearAccessToken() {
    setAccessToken(null);
  }

  Future<Response<T>> get<T>(
    String url, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
    Map<String, String>? headers,
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : await isPortOpen("127.0.0.1", port)
            ? "both"
            : "direct";
    final dio = _dio[mode]!;

    final options = _options(url, userAgent: userAgent, credentials: credentials);
    if (headers != null) {
      options.headers?.addAll(headers);
    }

    return dio.get<T>(
      url,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    CancelToken? cancelToken,
    dynamic data,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
    Map<String, String>? headers,
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : await isPortOpen("127.0.0.1", port)
            ? "both"
            : "direct";
    final dio = _dio[mode]!;

    final options = _options(url, userAgent: userAgent, credentials: credentials);
    if (headers != null) {
      options.headers?.addAll(headers);
    }

    return dio.post<T>(
      url,
      data: data,
      cancelToken: cancelToken,
      options: options,
    );
  }

  Future<Response> download(
    String url,
    String path, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : await isPortOpen("127.0.0.1", port)
            ? "both"
            : "direct";
    final dio = _dio[mode]!;
    return dio.download(
      url,
      path,
      cancelToken: cancelToken,
      options: _options(
        url,
        userAgent: userAgent,
        credentials: credentials,
      ),
    );
  }

  Options _options(
    String url, {
    String? userAgent,
    ({String username, String password})? credentials,
  }) {
    final uri = Uri.parse(url);

    String? userInfo;
    if (credentials != null) {
      userInfo = "${credentials.username}:${credentials.password}";
    } else if (uri.userInfo.isNotEmpty) {
      userInfo = uri.userInfo;
    }

    String? basicAuth;
    if (userInfo != null) {
      basicAuth = "Basic ${base64.encode(utf8.encode(userInfo))}";
    }

    return Options(
      headers: {
        if (userAgent != null) "User-Agent": userAgent,
        if (basicAuth != null) "authorization": basicAuth,
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
    );
  }
}
