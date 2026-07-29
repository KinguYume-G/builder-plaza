import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/role_posting.dart';

/// Drives the F8 Request Market: browsing, creating and closing postings.
/// Applying reuses the F7 pipeline (a collab request with context_ref).
class MarketProvider extends ChangeNotifier {
  MarketProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  List<RolePosting> _postings = const [];
  bool _loading = false;
  int _postingsRequestId = 0;
  String? _error;

  /// Posting ids with a close currently in flight, so the screen can disable
  /// that posting's Close button and a double-tap can't fire it twice.
  final Set<String> _closingIds = {};

  List<RolePosting> get postings => _postings;
  bool get loading => _loading;
  String? get error => _error;

  bool isClosing(String postingId) => _closingIds.contains(postingId);

  Future<void> fetchPostings({String? postingType, String? skill}) async {
    final requestId = ++_postingsRequestId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get<List<dynamic>>(
        '/role-postings',
        queryParameters: {
          'posting_type': ?postingType,
          'skill': ?skill,
        },
      );
      if (requestId != _postingsRequestId) return;
      _postings = (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RolePosting.fromJson)
          .toList();
    } catch (e) {
      if (requestId != _postingsRequestId) return;
      _error = ApiClient.describeError(e);
    } finally {
      if (requestId == _postingsRequestId) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// GET one posting with live repo activity; throws on failure.
  Future<RolePosting> fetchOne(String id) async {
    final res =
        await _api.dio.get<Map<String, dynamic>>('/role-postings/$id');
    return RolePosting.fromJson(res.data!);
  }

  /// POST a posting; null on error (with [error] set — includes the
  /// three-mandatory-field validation from the backend).
  Future<RolePosting?> createPosting(Map<String, dynamic> data) async {
    _error = null;
    try {
      final res = await _api.dio
          .post<Map<String, dynamic>>('/role-postings', data: data);
      final posting = RolePosting.fromJson(res.data!);
      _postings = [posting, ..._postings];
      notifyListeners();
      return posting;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  Future<RolePosting?> closePosting(String id) async {
    if (_closingIds.contains(id)) return null;
    _closingIds.add(id);
    _error = null;
    notifyListeners();
    try {
      final res =
          await _api.dio.delete<Map<String, dynamic>>('/role-postings/$id');
      final posting = RolePosting.fromJson(res.data!);
      _postings = _postings.where((entry) => entry.id != id).toList();
      return posting;
    } catch (e) {
      _error = ApiClient.describeError(e);
      return null;
    } finally {
      _closingIds.remove(id);
      notifyListeners();
    }
  }
}
