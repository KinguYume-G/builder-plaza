/// Models for F10 Verified Activity + Ownership Evidence.
///
/// Defensive parsing, matching the other model files.
library;

/// One verified GitHub event on the activity timeline.
class ActivityEvent {
  const ActivityEvent({
    required this.type,
    this.repo,
    this.detail,
    this.createdAt,
  });

  final String type;
  final String? repo;
  final String? detail;
  final DateTime? createdAt;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      type: json['type'] as String? ?? '',
      repo: json['repo'] as String?,
      detail: json['detail'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get typeLabel => switch (type) {
        'PushEvent' => 'PUSH',
        'PullRequestEvent' => 'PR',
        'CreateEvent' => 'BRANCH',
        'ReleaseEvent' => 'RELEASE',
        'IssuesEvent' => 'ISSUE',
        _ => type.toUpperCase(),
      };
}

/// The Verified Activity timeline response.
class ActivityTimeline {
  const ActivityTimeline({
    required this.githubLogin,
    required this.events,
    this.fetchedAt,
  });

  final String githubLogin;
  final List<ActivityEvent> events;
  final DateTime? fetchedAt;

  factory ActivityTimeline.fromJson(Map<String, dynamic> json) {
    return ActivityTimeline(
      githubLogin: json['github_login'] as String? ?? '',
      events: (json['events'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ActivityEvent.fromJson)
          .toList(),
      fetchedAt: json['fetched_at'] is String
          ? DateTime.tryParse(json['fetched_at'] as String)
          : null,
    );
  }
}

/// One week's activity count in the continuity chart.
class WeeklyActivity {
  const WeeklyActivity({required this.weekStart, required this.count});

  final String weekStart;
  final int count;

  factory WeeklyActivity.fromJson(Map<String, dynamic> json) {
    return WeeklyActivity(
      weekStart: json['week_start'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The role the user holds on one of their repositories.
class RepoRole {
  const RepoRole({
    required this.repo,
    required this.role,
    required this.stars,
    this.language,
  });

  final String repo;
  final String role;
  final int stars;
  final String? language;

  factory RepoRole.fromJson(Map<String, dynamic> json) {
    return RepoRole(
      repo: json['repo'] as String? ?? '',
      role: json['role'] as String? ?? 'owner',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      language: json['language'] as String?,
    );
  }
}

/// The Ownership Evidence response: continuity series + repo roles.
class OwnershipEvidence {
  const OwnershipEvidence({
    required this.githubLogin,
    required this.weeklyActivity,
    required this.activeWeeks,
    required this.totalWeeks,
    required this.repoRoles,
  });

  final String githubLogin;
  final List<WeeklyActivity> weeklyActivity;
  final int activeWeeks;
  final int totalWeeks;
  final List<RepoRole> repoRoles;

  factory OwnershipEvidence.fromJson(Map<String, dynamic> json) {
    return OwnershipEvidence(
      githubLogin: json['github_login'] as String? ?? '',
      weeklyActivity: (json['weekly_activity'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WeeklyActivity.fromJson)
          .toList(),
      activeWeeks: (json['active_weeks'] as num?)?.toInt() ?? 0,
      totalWeeks: (json['total_weeks'] as num?)?.toInt() ?? 0,
      repoRoles: (json['repo_roles'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RepoRole.fromJson)
          .toList(),
    );
  }
}
