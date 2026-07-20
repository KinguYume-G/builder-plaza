import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/project_card.dart';
import '../models/repo_activity.dart';

/// Drives the F3 Project Card feature: the user's own projects, the public
/// Plaza discovery feed, single-project detail, screenshot uploads, and the
/// user's collaboration intent.
///
/// All authenticated calls go through [ApiClient] (which attaches the Bearer
/// token). The one exception is the screenshot PUT to object storage, which
/// deliberately uses a *bare* Dio with no interceptors — see [uploadScreenshot].
class ProjectsProvider extends ChangeNotifier {
  ProjectsProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  /// A separate Dio with NO auth interceptor, used only to PUT screenshot bytes
  /// to the presigned storage URL. Sending our Bearer token to object storage
  /// (S3) would be wrong — the presigned URL is already the credential, and an
  /// extra Authorization header can make the signed request fail.
  final Dio _storageDio = Dio();

  List<ProjectCard> _mine = const [];
  List<ProjectCard> _discovery = const [];
  IntentBadge? _myIntent;

  bool _loadingMine = false;
  bool _loadingDiscovery = false;
  bool _uploading = false;
  String? _error;

  List<ProjectCard> get mine => _mine;
  List<ProjectCard> get discovery => _discovery;
  IntentBadge? get myIntent => _myIntent;
  bool get loadingMine => _loadingMine;
  bool get loadingDiscovery => _loadingDiscovery;
  bool get uploading => _uploading;
  String? get error => _error;

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// GET /projects/mine (Bearer) → the current user's projects, incl. archived.
  Future<void> fetchMine() async {
    _loadingMine = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get<List<dynamic>>('/projects/mine');
      _mine = _parseList(res.data);
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loadingMine = false;
      notifyListeners();
    }
  }

  /// GET /projects?stage=&q= → active projects for the public Plaza feed.
  Future<void> fetchDiscovery({String? stage, String? q}) async {
    _loadingDiscovery = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get<List<dynamic>>(
        '/projects',
        queryParameters: {
          if (stage != null && stage.isNotEmpty) 'stage': stage,
          if (q != null && q.isNotEmpty) 'q': q,
        },
      );
      _discovery = _parseList(res.data);
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loadingDiscovery = false;
      notifyListeners();
    }
  }

  /// GET /projects/{id} → a single project (throws on failure so callers can
  /// show a per-screen error).
  Future<ProjectCard> fetchOne(String id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/projects/$id');
    return ProjectCard.fromJson(res.data!);
  }

  /// GET /projects/{id}/repo-activity → live stats for the linked repos.
  Future<List<RepoActivity>> fetchRepoActivity(String id) async {
    final res =
        await _api.dio.get<List<dynamic>>('/projects/$id/repo-activity');
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RepoActivity.fromJson)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// POST /projects → create a project. Returns the new card, or null on error
  /// (with [error] set). Refreshes [mine] on success.
  Future<ProjectCard?> createProject({
    required String title,
    required String stage,
    String? needs,
    String? demoUrl,
    String? teamDivision,
    List<String> repoFullNames = const [],
  }) async {
    _error = null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/projects',
        data: {
          'title': title,
          'stage': stage,
          if (needs != null && needs.isNotEmpty) 'needs': needs,
          if (demoUrl != null && demoUrl.isNotEmpty) 'demo_url': demoUrl,
          if (teamDivision != null && teamDivision.isNotEmpty)
            'team_division': teamDivision,
          'repo_full_names': repoFullNames,
        },
      );
      final card = ProjectCard.fromJson(res.data!);
      _upsertMine(card);
      notifyListeners();
      return card;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  /// PATCH /projects/{id} → partial update. [patch] holds only changed fields
  /// (snake_case keys). Returns the updated card or null on error.
  Future<ProjectCard?> updateProject(
    String id,
    Map<String, dynamic> patch,
  ) async {
    _error = null;
    try {
      final res = await _api.dio.patch<Map<String, dynamic>>(
        '/projects/$id',
        data: patch,
      );
      final card = ProjectCard.fromJson(res.data!);
      _upsertMine(card);
      notifyListeners();
      return card;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  /// DELETE /projects/{id} → archive. Returns the archived card or null.
  Future<ProjectCard?> archiveProject(String id) async {
    _error = null;
    try {
      final res = await _api.dio.delete<Map<String, dynamic>>('/projects/$id');
      final card = ProjectCard.fromJson(res.data!);
      _upsertMine(card);
      // An archived project drops out of the public feed.
      _discovery = _discovery.where((p) => p.id != id).toList();
      notifyListeners();
      return card;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Screenshots
  // ---------------------------------------------------------------------------

  /// Uploads a picked image as a project screenshot in three steps:
  ///   1. POST /projects/{id}/screenshots-upload-url {content_type}
  ///      → { upload_url, key }   (authenticated, via [ApiClient]).
  ///   2. PUT the raw file bytes to `upload_url` using [_storageDio] — a BARE
  ///      Dio with NO Authorization header (this is object storage, not our
  ///      API). The `Content-Type` header MUST equal the content_type we asked
  ///      for so it matches the presigned signature.
  ///   3. POST /projects/{id}/screenshots {key} → the updated ProjectCard.
  ///
  /// Returns the updated card, or null on error (with [error] set).
  Future<ProjectCard?> uploadScreenshot(String projectId, XFile file) async {
    _error = null;
    _uploading = true;
    notifyListeners();
    try {
      final bytes = await file.readAsBytes();
      final contentType = _contentTypeFor(file);

      // Step 1 — ask our API for a presigned upload URL.
      final signRes = await _api.dio.post<Map<String, dynamic>>(
        '/projects/$projectId/screenshots-upload-url',
        data: {'content_type': contentType},
      );
      final uploadUrl = signRes.data!['upload_url'] as String;
      final key = signRes.data!['key'] as String;

      // Step 2 — PUT the bytes straight to storage with NO auth header.
      await _storageDio.put<void>(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
          // Prevent Dio from overriding the exact Content-Type we signed with.
          contentType: contentType,
        ),
      );

      // Step 3 — register the uploaded key against the project.
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/projects/$projectId/screenshots',
        data: {'key': key},
      );
      final card = ProjectCard.fromJson(res.data!);
      _upsertMine(card);
      notifyListeners();
      return card;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  /// DELETE /projects/{id}/screenshots {key} → the updated ProjectCard.
  Future<ProjectCard?> removeScreenshot(String projectId, String key) async {
    _error = null;
    try {
      final res = await _api.dio.delete<Map<String, dynamic>>(
        '/projects/$projectId/screenshots',
        data: {'key': key},
      );
      final card = ProjectCard.fromJson(res.data!);
      _upsertMine(card);
      notifyListeners();
      return card;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Intent (/me/intent)
  // ---------------------------------------------------------------------------

  /// GET /me/intent → the user's current intent (null if unset). Caches into
  /// [myIntent].
  Future<IntentBadge?> getIntent() async {
    _error = null;
    try {
      final res = await _api.dio.get('/me/intent');
      final data = res.data;
      _myIntent =
          data is Map<String, dynamic> ? IntentBadge.fromJson(data) : null;
    } catch (e) {
      _error = ApiClient.describeError(e);
      _myIntent = null;
    }
    notifyListeners();
    return _myIntent;
  }

  /// PUT /me/intent {intent_type, note?} → set/replace the intent.
  Future<IntentBadge?> setIntent(String intentType, {String? note}) async {
    _error = null;
    try {
      final res = await _api.dio.put<Map<String, dynamic>>(
        '/me/intent',
        data: {
          'intent_type': intentType,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      _myIntent = IntentBadge.fromJson(res.data!);
      notifyListeners();
      return _myIntent;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  /// DELETE /me/intent → clear the intent (204).
  Future<bool> clearIntent() async {
    _error = null;
    try {
      await _api.dio.delete('/me/intent');
      _myIntent = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<ProjectCard> _parseList(List<dynamic>? data) {
    return (data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProjectCard.fromJson)
        .toList();
  }

  /// Insert or replace a card in [_mine] (newest edits stay in place).
  void _upsertMine(ProjectCard card) {
    final idx = _mine.indexWhere((p) => p.id == card.id);
    if (idx == -1) {
      _mine = [card, ..._mine];
    } else {
      final next = [..._mine];
      next[idx] = card;
      _mine = next;
    }
  }

  /// Best-effort MIME type for a picked file. image_picker often leaves
  /// [XFile.mimeType] null on some platforms, so fall back to the extension.
  String _contentTypeFor(XFile file) {
    final declared = file.mimeType;
    if (declared != null && declared.isNotEmpty) return declared;
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
