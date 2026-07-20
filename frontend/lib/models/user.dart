/// A Builder Plaza user profile.
///
/// Matches the backend JSON contract exactly:
/// ```json
/// { "id": String, "github_login": String, "linkedin_sub": String?,
///   "primary_role": String, "completeness_pct": int, "trust_score": double,
///   "reverify_flag": bool, "avatar_url": String?, "onboarding_complete": bool,
///   "github_connected": bool, "linkedin_connected": bool,
///   "linkedin_headline": String? }
/// ```
class User {
  const User({
    required this.id,
    required this.githubLogin,
    required this.primaryRole,
    required this.completenessPct,
    required this.trustScore,
    required this.reverifyFlag,
    required this.onboardingComplete,
    required this.githubConnected,
    required this.linkedinConnected,
    this.linkedinSub,
    this.avatarUrl,
    this.linkedinHeadline,
  });

  final String id;
  final String githubLogin;
  final String? linkedinSub;

  /// One of "builder" | "collaborator" | "founder".
  final String primaryRole;
  final int completenessPct;
  final double trustScore;
  final bool reverifyFlag;
  final String? avatarUrl;

  /// Trust Gateway onboarding flags.
  final bool onboardingComplete;
  final bool githubConnected;
  final bool linkedinConnected;
  final String? linkedinHeadline;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      githubLogin: json['github_login'] as String,
      linkedinSub: json['linkedin_sub'] as String?,
      primaryRole: json['primary_role'] as String,
      completenessPct: (json['completeness_pct'] as num?)?.toInt() ?? 0,
      // trust_score may arrive as int or double.
      trustScore: (json['trust_score'] as num?)?.toDouble() ?? 0,
      reverifyFlag: json['reverify_flag'] as bool? ?? false,
      avatarUrl: json['avatar_url'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      githubConnected: json['github_connected'] as bool? ?? false,
      linkedinConnected: json['linkedin_connected'] as bool? ?? false,
      linkedinHeadline: json['linkedin_headline'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'github_login': githubLogin,
      'linkedin_sub': linkedinSub,
      'primary_role': primaryRole,
      'completeness_pct': completenessPct,
      'trust_score': trustScore,
      'reverify_flag': reverifyFlag,
      'avatar_url': avatarUrl,
      'onboarding_complete': onboardingComplete,
      'github_connected': githubConnected,
      'linkedin_connected': linkedinConnected,
      'linkedin_headline': linkedinHeadline,
    };
  }
}
