import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

enum HTTPMethod { get, post, put, delete, head }

class ExampleHTTPResult<T> {
  final bool isSuccess;
  final T? data;
  final String? message;
  final int? httpCode;

  const ExampleHTTPResult({
    required this.isSuccess,
    this.data,
    this.message,
    this.httpCode,
  });

  static ExampleHTTPResult<T> success<T>(T data, {int? httpCode}) {
    return ExampleHTTPResult<T>(
      isSuccess: true,
      data: data,
      httpCode: httpCode,
    );
  }

  static ExampleHTTPResult<T> failure<T>(String message, {int? httpCode}) {
    return ExampleHTTPResult<T>(
      isSuccess: false,
      message: message,
      httpCode: httpCode,
    );
  }
}

class ExampleHTTPUtility {
  static final ExampleHTTPUtility _instance = ExampleHTTPUtility._internal();

  factory ExampleHTTPUtility() => _instance;

  ExampleHTTPUtility._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ExampleConstants.serverURL,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cookies = await _loadCookies();
          if (cookies.isNotEmpty) {
            options.headers['Cookie'] = cookies;
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _saveCookies(response);
          handler.next(response);
        },
      ),
    );
  }

  late final Dio _dio;

  void updateEnvironment() {
    _dio.options.baseUrl = ExampleConstants.serverURL;
  }

  Future<ExampleHTTPResult<T>> request<T>(
    HTTPMethod method,
    String path, {
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? data,
  }) async {
    try {
      final Response<dynamic> response;
      switch (method) {
        case HTTPMethod.get:
          response = await _dio.get(path, queryParameters: parameters);
        case HTTPMethod.post:
          response = await _dio.post(path, data: data);
        case HTTPMethod.put:
          response = await _dio.put(path, data: data);
        case HTTPMethod.delete:
          response = await _dio.delete(path, data: data);
        case HTTPMethod.head:
          response = await _dio.head(path, queryParameters: parameters);
      }
      if (response.statusCode == 200) {
        return ExampleHTTPResult.success<T>(
          response.data as T,
          httpCode: response.statusCode,
        );
      }
      return ExampleHTTPResult.failure<T>(
        'HTTP Error: ${response.statusCode}',
        httpCode: response.statusCode,
      );
    } on DioException catch (error) {
      return ExampleHTTPResult.failure<T>(
        _errorMessage(error),
        httpCode: error.response?.statusCode,
      );
    }
  }

  static String _errorMessage(DioException error) {
    if (error.response != null) {
      return 'HTTP Error: ${error.response?.statusCode}, '
          '${error.response?.statusMessage ?? ''}';
    }
    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection Timeout';
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return 'Receive Timeout';
    }
    return error.error?.toString() ?? 'Unknown Error';
  }

  static Future<void> _saveCookies(Response<dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    final cookies = response.headers['Set-Cookie'];
    if (cookies != null && cookies.isNotEmpty) {
      final cookieString = cookies
          .map((cookie) => cookie.split(';').first)
          .join('; ');
      await prefs.setString('cookies', cookieString);
      if (kDebugMode) {
        debugPrint('Cookies saved: $cookieString');
      }
    }
  }

  static Future<String> _loadCookies() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cookies') ?? '';
  }
}
