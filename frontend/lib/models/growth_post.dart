/// Models for the F4 Growth Plaza feature.
///
/// Defensive parsing, same as project_card.dart: missing fields degrade to
/// defaults instead of throwing.
library;

import 'project_card.dart';

/// One normalised GitHub source event embedded in a growth post.
class GrowthEvent {
  const GrowthEvent({
    required this.type,
    required this.repo,
    this.actor,
    this.detail,
    this.createdAt,
  });

  final String type;
  final String repo;
  final String? actor;
  final String? detail;
  final DateTime? createdAt;

  factory GrowthEvent.fromJson(Map<String, dynamic> json) {
    return GrowthEvent(
      type: json['type'] as String? ?? '',
      repo: json['repo'] as String? ?? '',
      actor: json['actor'] as String?,
      detail: json['detail'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  /// A short human label for the event type, e.g. "PUSH" or "RELEASE".
  String get typeLabel => switch (type) {
        'PushEvent' => 'PUSH',
        'PullRequestEvent' => 'PR',
        'CreateEvent' => 'BRANCH',
        'ReleaseEvent' => 'RELEASE',
        'IssuesEvent' => 'ISSUE',
        _ => type.toUpperCase(),
      };
}

/// An AI-summarised batch of GitHub activity for one project.
class GrowthPost {
  const GrowthPost({
    required this.id,
    required this.projectId,
    required this.summary,
    required this.trigger,
    required this.sourceEvents,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final String summary;

  /// "manual" | "scheduled".
  final String trigger;
  final List<GrowthEvent> sourceEvents;
  final DateTime? createdAt;

  factory GrowthPost.fromJson(Map<String, dynamic> json) {
    return GrowthPost(
      id: json['id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      trigger: json['trigger'] as String? ?? 'manual',
      sourceEvents: (json['source_events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(GrowthEvent.fromJson)
          .toList(),
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

/// A growth post plus project/owner context, as served by GET /plaza.
class PlazaItem {
  const PlazaItem({
    required this.post,
    required this.projectTitle,
    required this.projectStage,
    required this.owner,
  });

  final GrowthPost post;
  final String projectTitle;
  final String projectStage;
  final OwnerLite owner;

  factory PlazaItem.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    return PlazaItem(
      post: json['post'] is Map<String, dynamic>
          ? GrowthPost.fromJson(json['post'] as Map<String, dynamic>)
          : GrowthPost.fromJson(const {}),
      projectTitle: json['project_title'] as String? ?? '',
      projectStage: json['project_stage'] as String? ?? 'idea',
      owner: ownerJson is Map<String, dynamic>
          ? OwnerLite.fromJson(ownerJson)
          : const OwnerLite(id: '', githubLogin: '', primaryRole: 'builder'),
    );
  }
}
