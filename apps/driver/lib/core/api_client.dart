import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dev_env.dart';
export 'dev_env.dart' show kApiBaseUrl;

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _ensureTokenLoaded();
          final token = _accessToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (err.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final opts = err.requestOptions;
                opts.headers['Authorization'] = 'Bearer $_accessToken';
                final clone = await _dio.fetch(opts);
                return handler.resolve(clone);
              } catch (_) {}
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  bool _prefsLoaded = false;

  Future<void> _ensureTokenLoaded() async {
    if (_prefsLoaded && _accessToken != null) return;
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('accessToken') ?? _accessToken;
    _refreshToken = prefs.getString('refreshToken') ?? _refreshToken;
    _prefsLoaded = true;
  }

  Future<void> saveTokens(String access, String refresh) async {
    _accessToken = access;
    _refreshToken = refresh;
    _prefsLoaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', access);
    await prefs.setString('refreshToken', refresh);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  Future<bool> _tryRefresh() async {
    await _ensureTokenLoaded();
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await Dio(
        BaseOptions(baseUrl: kApiBaseUrl, headers: {'Content-Type': 'application/json'}),
      ).post('/auth/refresh', data: {'refreshToken': refresh});
      final body = res.data;
      final data = body is Map && body['data'] is Map
          ? Map<String, dynamic>.from(body['data'] as Map)
          : Map<String, dynamic>.from(body as Map);
      final access = data['accessToken'] as String?;
      final nextRefresh = data['refreshToken'] as String?;
      if (access == null || nextRefresh == null) return false;
      await saveTokens(access, nextRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _friendlyError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? serverMsg;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) serverMsg = err['message']?.toString();
    }
    if (status == 401) {
      return 'Session expired or not logged in (401). Log out and login with OTP again.';
    }
    if (status == 403) return serverMsg ?? 'Forbidden (403)';
    if (serverMsg != null) return serverMsg;
    if (e.type == DioExceptionType.connectionError) {
      return 'Cannot reach API at $kApiBaseUrl. Is the backend running?';
    }
    return e.message ?? e.toString();
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? data]) async {
    try {
      final res = await _dio.post(path, data: data);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> get(String path) async {
    try {
      final res = await _dio.get(path);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e));
    }
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? data]) async {
    try {
      final res = await _dio.patch(path, data: data);
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (e) {
      throw Exception(_friendlyError(e));
    }
  }
}
