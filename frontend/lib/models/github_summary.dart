/// A language + repo-count pair from the GitHub summary.
///
/// Matches `{ "language": String, "count": int }`.
class LangCount {
  const LangCount({required this.language, required this.count});

  final String language;
  final int count;

  factory LangCount.fromJson(Map<String, dynamic> json) {
    return LangCount(
      language: json['language'] as String? ?? '?',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A snapshot of a user's public GitHub activity, used to verify their work.
///
/// Matches the backend JSON contract:
/// ```json
/// { "login": String, "name": String?, "avatar_url": String?,
///   "public_repos": int, "followers": int,
///   "top_languages": [{"language": String, "count": int}],
///   "topics": [String], "recent_activity_count": int, "stars": int }
/// ```
class GithubSummary {
  const GithubSummary({
    required this.login,
    required this.publicRepos,
    required this.followers,
    required this.topLanguages,
    required this.topics,
    required this.recentActivityCount,
    required this.stars,
    this.name,
    this.avatarUrl,
  });

  final String login;
  final String? name;
  final String? avatarUrl;
  final int publicRepos;
  final int followers;
  final List<LangCount> topLanguages;
  final List<String> topics;
  final int recentActivityCount;
  final int stars;

  factory GithubSummary.fromJson(Map<String, dynamic> json) {
    final langs = (json['top_languages'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(LangCount.fromJson)
        .toList();
    final topics = (json['topics'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    return GithubSummary(
      login: json['login'] as String? ?? '',
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      publicRepos: (json['public_repos'] as num?)?.toInt() ?? 0,
      followers: (json['followers'] as num?)?.toInt() ?? 0,
      topLanguages: langs,
      topics: topics,
      recentActivityCount: (json['recent_activity_count'] as num?)?.toInt() ?? 0,
      stars: (json['stars'] as num?)?.toInt() ?? 0,
    );
  }
}
