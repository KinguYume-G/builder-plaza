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
  String? _error;

  List<RolePosting> get postings => _postings;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetchPostings({String? postingType, String? skill}) async {
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
      _postings = (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RolePosting.fromJson)
          .toList();
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loading = false;
      notifyListeners();
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
    _error = null;
    try {
      final res =
          await _api.dio.delete<Map<String, dynamic>>('/role-postings/$id');
      final posting = RolePosting.fromJson(res.data!);
      _postings = _postings.where((entry) => entry.id != id).toList();
      notifyListeners();
      return posting;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }
}
