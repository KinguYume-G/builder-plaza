import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/match.dart';

/// Drives the F5 matching engine screens: the match round, dismissals, and
/// plain-language credibility summaries.
class MatchesProvider extends ChangeNotifier {
  MatchesProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  List<MatchItem> _matches = const [];
  bool _loading = false;
  String? _error;

  List<MatchItem> get matches => _matches;
  bool get loading => _loading;
  String? get error => _error;

  /// GET /matches — refresh=true re-runs the engine (embed → recall → GPR →
  /// ε-greedy → reasons), so pull-to-refresh genuinely reshuffles exploration.
  Future<void> fetchMatches({bool refresh = true}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.dio.get<List<dynamic>>(
        '/matches',
        queryParameters: {'refresh': refresh},
      );
      _matches = (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(MatchItem.fromJson)
          .toList();
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// POST /matches/{id}/dismiss — the candidate never resurfaces.
  Future<bool> dismiss(String matchId) async {
    try {
      await _api.dio.post('/matches/$matchId/dismiss');
      _matches = _matches.where((match) => match.id != matchId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return false;
    }
  }

  /// GET /users/{id}/credibility-summary — throws on failure.
  Future<CredibilitySummary> fetchCredibility(String userId) async {
    final res = await _api.dio
        .get<Map<String, dynamic>>('/users/$userId/credibility-summary');
    return CredibilitySummary.fromJson(res.data!);
  }
}
