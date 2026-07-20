/// Models for the F6 Trust Score breakdown + peer reviews.
library;

class TrustComponent {
  const TrustComponent({
    required this.key,
    required this.label,
    required this.weight,
    required this.available,
    required this.simulated,
    this.score,
    this.detail,
  });

  final String key;
  final String label;
  final double? score;
  final double weight;
  final bool available;
  final bool simulated;
  final String? detail;

  factory TrustComponent.fromJson(Map<String, dynamic> json) {
    return TrustComponent(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      available: json['available'] as bool? ?? false,
      simulated: json['simulated'] as bool? ?? false,
      detail: json['detail'] as String?,
    );
  }
}

class TrustScore {
  const TrustScore({
    required this.githubLogin,
    required this.total,
    required this.components,
  });

  final String githubLogin;
  final double total;
  final List<TrustComponent> components;

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      githubLogin: json['github_login'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      components: (json['components'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TrustComponent.fromJson)
          .toList(),
    );
  }
}

class PeerReviewItem {
  const PeerReviewItem({
    required this.reviewerLogin,
    required this.stars,
    required this.tags,
    this.createdAt,
  });

  final String reviewerLogin;
  final int stars;
  final List<String> tags;
  final DateTime? createdAt;

  factory PeerReviewItem.fromJson(Map<String, dynamic> json) {
    return PeerReviewItem(
      reviewerLogin: json['reviewer_login'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag.toString())
          .toList(),
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
