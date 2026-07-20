/// Models for F7 Controlled DM: collaboration requests, conversations,
/// messages.
library;

const List<String> kRequestIntentTypes = [
  'cofounder',
  'maintainer',
  'collaboration',
  'chat',
];

const Map<String, String> kRequestIntentLabels = {
  'cofounder': 'Co-founder',
  'maintainer': 'Maintainer',
  'collaboration': 'Collaboration',
  'chat': 'Just chat',
};

class UserLite {
  const UserLite({
    required this.id,
    required this.githubLogin,
    required this.primaryRole,
    this.avatarUrl,
  });

  final String id;
  final String githubLogin;
  final String primaryRole;
  final String? avatarUrl;

  factory UserLite.fromJson(Map<String, dynamic> json) {
    return UserLite(
      id: json['id'] as String? ?? '',
      githubLogin: json['github_login'] as String? ?? '',
      primaryRole: json['primary_role'] as String? ?? 'builder',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class CollabRequestItem {
  const CollabRequestItem({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.intentType,
    required this.pitch,
    required this.state,
    this.conversationId,
    this.createdAt,
  });

  final String id;
  final UserLite fromUser;
  final UserLite toUser;
  final String intentType;
  final String pitch;

  /// pending | accepted | declined | withdrawn
  final String state;
  final String? conversationId;
  final DateTime? createdAt;

  String get intentLabel => kRequestIntentLabels[intentType] ?? intentType;

  factory CollabRequestItem.fromJson(Map<String, dynamic> json) {
    return CollabRequestItem(
      id: json['id'] as String? ?? '',
      fromUser: json['from_user'] is Map<String, dynamic>
          ? UserLite.fromJson(json['from_user'] as Map<String, dynamic>)
          : const UserLite(id: '', githubLogin: '', primaryRole: 'builder'),
      toUser: json['to_user'] is Map<String, dynamic>
          ? UserLite.fromJson(json['to_user'] as Map<String, dynamic>)
          : const UserLite(id: '', githubLogin: '', primaryRole: 'builder'),
      intentType: json['intent_type'] as String? ?? 'chat',
      pitch: json['pitch'] as String? ?? '',
      state: json['state'] as String? ?? 'pending',
      conversationId: json['conversation_id'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class MessageItem {
  const MessageItem({
    required this.id,
    required this.senderId,
    required this.senderLogin,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderLogin;
  final String body;
  final DateTime? createdAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    return MessageItem(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      senderLogin: json['sender_login'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class ConversationItem {
  const ConversationItem({
    required this.id,
    required this.collabRequestId,
    required this.counterpart,
    required this.intentType,
    this.lastMessage,
  });

  final String id;
  final String collabRequestId;
  final UserLite counterpart;
  final String intentType;
  final MessageItem? lastMessage;

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'] as String? ?? '',
      collabRequestId: json['collab_request_id'] as String? ?? '',
      counterpart: json['counterpart'] is Map<String, dynamic>
          ? UserLite.fromJson(json['counterpart'] as Map<String, dynamic>)
          : const UserLite(id: '', githubLogin: '', primaryRole: 'builder'),
      intentType: json['intent_type'] as String? ?? 'chat',
      lastMessage: json['last_message'] is Map<String, dynamic>
          ? MessageItem.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
    );
  }
}
