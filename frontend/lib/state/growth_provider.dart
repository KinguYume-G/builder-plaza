import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/growth_post.dart';

/// Drives the F4 Growth Plaza: the cross-project growth feed, per-project
/// growth history, and the owner-triggered manual refresh.
class GrowthProvider extends ChangeNotifier {
  GrowthProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  List<PlazaItem> _feed = const [];
  bool _loadingFeed = false;
  bool _refreshing = false;
  String? _error;

  List<PlazaItem> get feed => _feed;
  bool get loadingFeed => _loadingFeed;
  bool get refreshing => _refreshing;
  String? get error => _error;

  /// GET /plaza → growth posts across all active projects, newest first.
  Future<void> fetchFeed({String? role, String? stage}) async {
    _loadingFeed = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get<List<dynamic>>(
        '/plaza',
        queryParameters: {
          if (role != null && role.isNotEmpty) 'role': role,
          if (stage != null && stage.isNotEmpty) 'stage': stage,
        },
      );
      _feed = (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PlazaItem.fromJson)
          .toList();
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loadingFeed = false;
      notifyListeners();
    }
  }

  /// GET /projects/{id}/growth → one project's growth history, newest first.
  /// Throws on failure so the detail screen can show a per-section error.
  Future<List<GrowthPost>> fetchProjectGrowth(String projectId) async {
    final res =
        await _api.dio.get<List<dynamic>>('/projects/$projectId/growth');
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(GrowthPost.fromJson)
        .toList();
  }

  /// POST /projects/{id}/refresh-growth → poll GitHub + summarise.
  ///
  /// Returns the new post, or null when there was no new activity OR the call
  /// failed (check [error] to tell the two apart — it is null on "no news").
  Future<GrowthPost?> refreshGrowth(String projectId) async {
    _refreshing = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio
          .post<Map<String, dynamic>>('/projects/$projectId/refresh-growth');
      final data = res.data;
      if (data == null || data['refreshed'] != true || data['post'] == null) {
        return null; // no new activity since the last post
      }
      return GrowthPost.fromJson(data['post'] as Map<String, dynamic>);
    } catch (e) {
      _error = ApiClient.describeError(e);
      return null;
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }
}
