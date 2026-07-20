/// Models for the F3 Project Card feature.
///
/// Every `fromJson` parses defensively: the backend is built in parallel, so a
/// missing or wrongly-typed field must degrade to a sensible default instead of
/// throwing and taking down the whole list.
library;

/// The canonical project stages, in lifecycle order.
///
/// The Plaza filter row and the form's stage picker both iterate this list, so
/// it is the single source of truth for valid stage values.
const List<String> kStages = [
  'idea',
  'prototype',
  'building',
  'launched',
  'scaling',
];

/// Human-readable label for a stage value (falls back to the raw value).
const Map<String, String> kStageLabels = {
  'idea': 'Idea',
  'prototype': 'Prototype',
  'building': 'Building',
  'launched': 'Launched',
  'scaling': 'Scaling',
};

String stageLabel(String stage) => kStageLabels[stage] ?? stage;

/// The four intent types a user can advertise on their profile.
const List<String> kIntentTypes = [
  'seeking_cofounder',
  'seeking_maintainer',
  'open_to_chat',
  'not_open',
];

/// Human-readable label for an intent type (falls back to the raw value).
const Map<String, String> kIntentLabels = {
  'seeking_cofounder': 'Seeking co-founder',
  'seeking_maintainer': 'Seeking maintainer',
  'open_to_chat': 'Open to chat',
  'not_open': 'Not open',
};

String intentLabel(String type) => kIntentLabels[type] ?? type;

/// A single uploaded screenshot: the storage [key] plus a (presigned) [url].
class Screenshot {
  const Screenshot({required this.key, required this.url});

  final String key;
  final String url;

  factory Screenshot.fromJson(Map<String, dynamic> json) {
    return Screenshot(
      key: json['key'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

/// A trimmed-down view of a project's owner, embedded in each [ProjectCard].
class OwnerLite {
  const OwnerLite({
    required this.id,
    required this.githubLogin,
    required this.primaryRole,
    this.avatarUrl,
  });

  final String id;
  final String githubLogin;
  final String primaryRole;
  final String? avatarUrl;

  factory OwnerLite.fromJson(Map<String, dynamic> json) {
    return OwnerLite(
      id: json['id'] as String? ?? '',
      githubLogin: json['github_login'] as String? ?? '',
      primaryRole: json['primary_role'] as String? ?? 'builder',
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

/// A user's advertised collaboration intent.
///
/// Embedded on a [ProjectCard] (as the owner's intent) and also returned
/// standalone by the `/me/intent` endpoints.
class IntentBadge {
  const IntentBadge({required this.intentType, this.note});

  final String intentType;
  final String? note;

  String get label => intentLabel(intentType);

  factory IntentBadge.fromJson(Map<String, dynamic> json) {
    return IntentBadge(
      intentType: json['intent_type'] as String? ?? 'open_to_chat',
      note: json['note'] as String?,
    );
  }
}

/// A project posted on the Plaza. Matches the frozen backend JSON contract.
class ProjectCard {
  const ProjectCard({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.stage,
    required this.repoFullNames,
    required this.screenshots,
    required this.status,
    required this.owner,
    this.needs,
    this.demoUrl,
    this.teamDivision,
    this.intent,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ownerId;
  final String title;
  final String stage;
  final String? needs;
  final String? demoUrl;
  final String? teamDivision;
  final List<String> repoFullNames;
  final List<Screenshot> screenshots;

  /// One of "active" | "archived".
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final OwnerLite owner;
  final IntentBadge? intent;

  bool get isArchived => status == 'archived';

  factory ProjectCard.fromJson(Map<String, dynamic> json) {
    final repos = (json['repo_full_names'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final shots = (json['screenshots'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Screenshot.fromJson)
        .toList();
    final ownerJson = json['owner'];
    final intentJson = json['intent'];

    return ProjectCard(
      id: json['id'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      stage: json['stage'] as String? ?? 'idea',
      needs: json['needs'] as String?,
      demoUrl: json['demo_url'] as String?,
      teamDivision: json['team_division'] as String?,
      repoFullNames: repos,
      screenshots: shots,
      status: json['status'] as String? ?? 'active',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      owner: ownerJson is Map<String, dynamic>
          ? OwnerLite.fromJson(ownerJson)
          : const OwnerLite(id: '', githubLogin: '', primaryRole: 'builder'),
      intent: intentJson is Map<String, dynamic>
          ? IntentBadge.fromJson(intentJson)
          : null,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
