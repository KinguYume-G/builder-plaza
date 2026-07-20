import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Thin Dio wrapper (singleton) for talking to the Builder Plaza backend.
///
/// An interceptor attaches `Authorization: Bearer <token>` to every request
/// when a token is stored. The token is persisted via shared_preferences so it
/// survives app restarts.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        // Don't throw on 4xx so callers can read structured error bodies.
        headers: {'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const String _tokenKey = 'bp_access_token';

  static final ApiClient instance = ApiClient._internal();

  late final Dio _dio;

  /// In-memory cache of the token to avoid a disk read on every request.
  String? _cachedToken;

  Dio get dio => _dio;

  Future<String?> _readToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  Future<void> setToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await _readToken();
    return token != null && token.isNotEmpty;
  }

  /// Turns a Dio error / exception into a short human-readable message.
  static String describeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return status != null
            ? 'HTTP $status: ${data['detail']}'
            : '${data['detail']}';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Cannot reach backend at $apiBaseUrl';
      }
      if (status != null) return 'HTTP $status';
      return error.message ?? 'Network error';
    }
    return error.toString();
  }
}
