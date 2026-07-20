/// Models for the F5 matching engine.
library;

class MatchCandidate {
  const MatchCandidate({
    required this.id,
    required this.githubLogin,
    required this.primaryRole,
    required this.trustScore,
    this.avatarUrl,
    this.headline,
  });

  final String id;
  final String githubLogin;
  final String primaryRole;
  final double trustScore;
  final String? avatarUrl;
  final String? headline;

  factory MatchCandidate.fromJson(Map<String, dynamic> json) {
    return MatchCandidate(
      id: json['id'] as String? ?? '',
      githubLogin: json['github_login'] as String? ?? '',
      primaryRole: json['primary_role'] as String? ?? 'builder',
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      headline: json['headline'] as String?,
    );
  }
}

class MatchItem {
  const MatchItem({
    required this.id,
    required this.candidate,
    required this.score,
    required this.exploratory,
    required this.matchReason,
    required this.state,
  });

  final String id;
  final MatchCandidate candidate;
  final double score;
  final bool exploratory;
  final String matchReason;
  final String state;

  factory MatchItem.fromJson(Map<String, dynamic> json) {
    return MatchItem(
      id: json['id'] as String? ?? '',
      candidate: json['candidate'] is Map<String, dynamic>
          ? MatchCandidate.fromJson(json['candidate'] as Map<String, dynamic>)
          : const MatchCandidate(
              id: '', githubLogin: '', primaryRole: 'builder', trustScore: 0),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      exploratory: json['exploratory'] as bool? ?? false,
      matchReason: json['match_reason'] as String? ?? '',
      state: json['state'] as String? ?? 'active',
    );
  }
}

class CredibilitySummary {
  const CredibilitySummary({
    required this.githubLogin,
    required this.summary,
    required this.highlights,
  });

  final String githubLogin;
  final String summary;
  final List<String> highlights;

  factory CredibilitySummary.fromJson(Map<String, dynamic> json) {
    return CredibilitySummary(
      githubLogin: json['github_login'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
