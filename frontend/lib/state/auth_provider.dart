import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/github_summary.dart';
import '../models/linkedin_profile.dart';
import '../models/user.dart';

/// Holds the authenticated user and drives the auth + Trust Gateway onboarding
/// flows (github-connect / linkedin-bind / role / load-me / logout).
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

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

  /// GET /me (Bearer) → set [currentUser].
  Future<bool> loadMe() async {
    _error = null;
    _setLoading(true);
    try {
      final res = await _api.dio.get<Map<String, dynamic>>('/me');
      _currentUser = User.fromJson(res.data!);
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
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

  /// Clear token + user + cached summary.
  Future<void> logout() async {
    await _api.clearToken();
    _currentUser = null;
    _githubSummary = null;
    _error = null;
    notifyListeners();
  }
}
