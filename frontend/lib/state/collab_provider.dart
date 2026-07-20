import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../models/collab.dart';

/// Drives F7 Controlled DM: sending structured requests, the inbox/sent
/// lists, accept/decline/withdraw, and conversations with 10s polling.
class CollabProvider extends ChangeNotifier {
  CollabProvider({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  List<CollabRequestItem> _inbox = const [];
  List<CollabRequestItem> _sent = const [];
  List<ConversationItem> _conversations = const [];
  bool _loading = false;
  String? _error;

  List<CollabRequestItem> get inbox => _inbox;
  List<CollabRequestItem> get sent => _sent;
  List<ConversationItem> get conversations => _conversations;
  bool get loading => _loading;
  String? get error => _error;

  int get pendingInboxCount =>
      _inbox.where((request) => request.state == 'pending').length;

  Future<void> fetchAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.dio.get<List<dynamic>>('/requests/inbox'),
        _api.dio.get<List<dynamic>>('/requests/sent'),
        _api.dio.get<List<dynamic>>('/conversations'),
      ]);
      _inbox = _parseRequests(results[0].data);
      _sent = _parseRequests(results[1].data);
      _conversations = (results[2].data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ConversationItem.fromJson)
          .toList();
    } catch (e) {
      _error = ApiClient.describeError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// POST /requests → the created request, or null (with [error] set).
  Future<CollabRequestItem?> sendRequest({
    required String toUser,
    required String intentType,
    required String pitch,
    String? contextRef,
  }) async {
    _error = null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/requests',
        data: {
          'to_user': toUser,
          'intent_type': intentType,
          'pitch': pitch,
          'context_ref': ?contextRef,
        },
      );
      final request = CollabRequestItem.fromJson(res.data!);
      _sent = [request, ..._sent];
      notifyListeners();
      return request;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  Future<CollabRequestItem?> _action(String requestId, String action) async {
    _error = null;
    try {
      final res = await _api.dio
          .post<Map<String, dynamic>>('/requests/$requestId/$action');
      final updated = CollabRequestItem.fromJson(res.data!);
      _inbox = _replace(_inbox, updated);
      _sent = _replace(_sent, updated);
      notifyListeners();
      return updated;
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  Future<CollabRequestItem?> accept(String requestId) =>
      _action(requestId, 'accept');
  Future<CollabRequestItem?> decline(String requestId) =>
      _action(requestId, 'decline');
  Future<CollabRequestItem?> withdraw(String requestId) =>
      _action(requestId, 'withdraw');

  /// GET messages (optionally incremental via [afterId]); throws on failure.
  Future<List<MessageItem>> fetchMessages(
    String conversationId, {
    String? afterId,
  }) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/conversations/$conversationId/messages',
      queryParameters: {'after': ?afterId},
    );
    return (res.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MessageItem.fromJson)
        .toList();
  }

  /// POST a message; returns it or null (with [error] set).
  Future<MessageItem?> sendMessage(String conversationId, String body) async {
    _error = null;
    try {
      final res = await _api.dio.post<Map<String, dynamic>>(
        '/conversations/$conversationId/messages',
        data: {'body': body},
      );
      return MessageItem.fromJson(res.data!);
    } catch (e) {
      _error = ApiClient.describeError(e);
      notifyListeners();
      return null;
    }
  }

  List<CollabRequestItem> _parseRequests(List<dynamic>? data) {
    return (data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CollabRequestItem.fromJson)
        .toList();
  }

  List<CollabRequestItem> _replace(
    List<CollabRequestItem> list,
    CollabRequestItem updated,
  ) {
    return [
      for (final request in list)
        request.id == updated.id ? updated : request,
    ];
  }
}
