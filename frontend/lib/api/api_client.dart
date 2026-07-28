import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'connection_tuning_web.dart'
    if (dart.library.io) 'connection_tuning_io.dart';

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
        // Dio's default validateStatus is left in place, so any non-2xx throws
        // a DioException. Callers rely on that: they catch and hand the error
        // to [describeError], which reads the structured body off
        // `error.response`. Do not add a permissive validateStatus here — it
        // would turn every 4xx into an apparent success at the call sites.
        headers: {'Accept': 'application/json'},
      ),
    );

    tuneConnectionReuse(_dio);

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
      final detail = data is Map ? data['detail'] : null;
      // FastAPI returns `detail` as a plain string for our own HTTPExceptions,
      // but as a LIST of per-field records for Pydantic validation failures
      // (422). Interpolating that list dumps `[{type: literal_error, loc: ...`
      // straight into the UI, so unpack it into the field messages instead.
      if (detail is List) {
        final messages = detail
            .whereType<Map>()
            .map((e) => e['msg'])
            .whereType<String>()
            .toList();
        if (messages.isNotEmpty) return messages.join('; ');
      } else if (detail != null) {
        return status != null ? 'HTTP $status: $detail' : '$detail';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Cannot reach backend at $apiBaseUrl';
      }
      // Dio's own message for these is a paragraph of English telling the user
      // to raise RequestOptions.receiveTimeout — useless to them, so replace it.
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'The server took too long to respond. Please try again.';
      }
      if (status != null) return 'HTTP $status';
      return error.message ?? 'Network error';
    }
    return error.toString();
  }
}
