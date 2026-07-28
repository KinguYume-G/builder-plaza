import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/connection_tuning_web.dart'
    if (dart.library.io) '../api/connection_tuning_io.dart';
import '../models/github_summary.dart';
import '../models/linkedin_profile.dart';
import '../models/user.dart';

/// Holds the authenticated user and drives the auth + Trust Gateway onboarding
/// flows (github-connect / linkedin-bind / role / load-me / logout).
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? api}) : _api = api ?? ApiClient.instance {
    tuneConnectionReuse(_storageDio);
  }

  final ApiClient _api;

  /// A single bare Dio (no auth interceptor) for the presigned avatar PUT.
  /// Mirrors ProjectsProvider's `_storageDio`. This used to be a `Dio()`
  /// constructed per upload and never closed, which leaked a connection pool on
  /// every avatar change.
  final Dio _storageDio = Dio();

  User? _currentUser;
  GithubSummary? _githubSummary;
  bool _loading = false;
  bool _bootstrapped = false;
  String? _error;

  User? get currentUser => _currentUser;
  GithubSummary? get githubSummary => _githubSummary;
  bool get loading => _loading;
  bool get bootstrapped => _bootstrapped;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  /// Drops the current error. Call this when navigating away from the screen
  /// that produced it, so the next screen doesn't open showing a stale failure
  /// the user has already moved past.
  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// On app start: if a token is stored, restore [currentUser] via GET /me so
  /// router gating works across reloads. Safe to call more than once.
  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    if (await _api.hasToken()) {
      await loadMe();
    }
    _bootstrapped = true;
    notifyListeners();
  }

  /// POST /auth/dev-login → store token → set [currentUser]. Dev tool only.
  ///
  /// Returns true on success. On failure sets [error] and returns false.
  Future<bool> devLogin({
    required String githubLogin,
    required String primaryRole,
  }) async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/dev-login',
        data: {
          'github_login': githubLogin,
          'primary_role': primaryRole,
        },
      );
      final data = res.data!;
      await _api.setToken(data['access_token'] as String);
      _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// POST /auth/github/connect {github_login} → store token, set [currentUser]
  /// and [githubSummary].
  ///
  /// Returns true on success. On failure sets [error] and returns false.
  Future<bool> connectGithub(String githubLogin) async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/github/connect',
        data: {'github_login': githubLogin},
      );
      final data = res.data!;
      await _api.setToken(data['access_token'] as String);
      _currentUser = User.fromJson(data['user'] as Map<String, dynamic>);
      _githubSummary =
          GithubSummary.fromJson(data['github'] as Map<String, dynamic>);
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// GET /auth/linkedin/mode → which LinkedIn onboarding path the backend is
  /// configured for: "live" (real OIDC redirect) or "simulated" (mock consent).
  ///
  /// Falls back to "simulated" on any failure so the safe mock path is used
  /// rather than accidentally exposing a broken live flow.
  Future<String> fetchLinkedInMode() async {
    try {
      final res =
          await _api.dio.get<Map<String, dynamic>>('/auth/linkedin/mode');
      final mode = res.data?['mode'] as String?;
      return mode == 'live' ? 'live' : 'simulated';
    } catch (e) {
      _error = ApiClient.describeError(e);
      return 'simulated';
    }
  }

  /// GET /auth/linkedin/login (Bearer) → the real LinkedIn OIDC `authorize_url`
  /// the browser should be redirected to. Returns null on failure and sets
  /// [error].
  Future<String?> linkedInLoginUrl() async {
    _error = null;
    _setLoading(true);
    try {
      final res =
          await _api.dio.get<Map<String, dynamic>>('/auth/linkedin/login');
      return res.data?['authorize_url'] as String?;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// GET /auth/linkedin/profiles → the list of (simulated) profiles to choose
  /// from. Returns an empty list on failure and sets [error].
  Future<List<LinkedInProfile>> fetchLinkedInProfiles() async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.get<List<dynamic>>('/auth/linkedin/profiles');
      return (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LinkedInProfile.fromJson)
          .toList();
    } catch (e) {
      _error = ApiClient.describeError(e);
      return const [];
    } finally {
      _setLoading(false);
    }
  }

  /// POST /auth/linkedin/bind {profile_id} → update [currentUser].
  Future<bool> bindLinkedIn(String profileId) async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/auth/linkedin/bind',
        data: {'profile_id': profileId},
      );
      _currentUser = User.fromJson(res.data!);
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// POST /me/role {primary_role} → update [currentUser].
  Future<bool> confirmRole(String role) async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/me/role',
        data: {'primary_role': role},
      );
      _currentUser = User.fromJson(res.data!);
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// GET /me (Bearer) → set [currentUser]. NFR: the last successful profile
  /// is cached so the app still shows YOUR profile read-only when offline.
  Future<bool> loadMe() async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/me');
      _currentUser = User.fromJson(res.data!);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bp_cache_me', jsonEncode(res.data));
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('bp_cache_me');
      if (cached != null && _currentUser == null) {
        _currentUser =
            User.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        return true; // offline read-only session
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// GET /me/github-summary (Bearer) → refresh [githubSummary].
  Future<void> loadGithubSummary() async {
    try {
      final res =
          await _api.dio.get<Map<String, dynamic>>('/me/github-summary');
      _githubSummary = GithubSummary.fromJson(res.data!);
      notifyListeners();
    } catch (_) {
      // Non-fatal — the home screen degrades gracefully without a summary.
    }
  }

  /// F2: upload a profile avatar via the presigned-S3 three-step flow
  /// (mirrors the F3 screenshot upload). Refreshes [currentUser] on success.
  Future<bool> uploadAvatar(XFile file) async {
    _error = null;
    try {
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      final contentType = file.mimeType ??
          (name.endsWith('.png')
              ? 'image/png'
              : name.endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg');

      final signRes = await _api.dio.post<Map<String, dynamic>>(
        '/me/avatar-upload-url',
        data: {'content_type': contentType},
      );
      final uploadUrl = signRes.data!['upload_url'] as String;
      final key = signRes.data!['key'] as String;

      // Bare Dio: the presigned URL is the credential; our Bearer token must
      // NOT be sent to object storage.
      await _storageDio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          contentType: contentType,
        ),
      );

      final res = await _api.dio
          .post<Map<String, dynamic>>('/me/avatar', data: {'key': key});
      _currentUser = User.fromJson(res.data!);
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return false;
    }
  }

  /// Test-only: seed [currentUser] directly so widget tests can reach the
  /// authenticated UI without a real network round trip.
  @visibleForTesting
  void debugSetUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Clear token + user + cached summary.
  Future<void> logout() async {
    await _api.clearToken();
    _currentUser = null;
    _githubSummary = null;
    _error = null;
    notifyListeners();
  }
}
