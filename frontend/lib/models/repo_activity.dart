/// Live activity for a repo linked to a project, from GET
/// `/projects/{id}/repo-activity`.
///
/// Each entry corresponds to one `owner/repo` in the project. When GitHub can't
/// be reached (or the repo is missing) the backend returns the same shape with
/// [error] set, so the detail screen can show a muted "activity unavailable"
/// row instead of failing the whole list.
class RepoActivity {
  const RepoActivity({
    required this.repo,
    this.htmlUrl,
    this.stars,
    this.language,
    this.pushedAt,
    this.openIssues,
    this.description,
    this.error,
  });

  final String repo;
  final String? htmlUrl;
  final int? stars;
  final String? language;
  final DateTime? pushedAt;
  final int? openIssues;
  final String? description;
  final String? error;

  bool get hasError => error != null && error!.isNotEmpty;

  factory RepoActivity.fromJson(Map<String, dynamic> json) {
    return RepoActivity(
      repo: json['repo'] as String? ?? '',
      htmlUrl: json['html_url'] as String?,
      stars: (json['stars'] as num?)?.toInt(),
      language: json['language'] as String?,
      pushedAt: _parseDate(json['pushed_at']),
      openIssues: (json['open_issues'] as num?)?.toInt(),
      description: json['description'] as String?,
      error: json['error'] as String?,
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}
