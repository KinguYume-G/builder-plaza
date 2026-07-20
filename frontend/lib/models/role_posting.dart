/// Models for the F8 Request Market.
library;

import 'collab.dart';

const List<String> kAccessTiers = ['claim_an_issue', 'limited', 'full'];

const Map<String, String> kAccessTierLabels = {
  'claim_an_issue': 'Claim an issue',
  'limited': 'Limited access',
  'full': 'Full access',
};

class PostingRepo {
  const PostingRepo({
    required this.repo,
    required this.stars,
    this.language,
    this.error,
  });

  final String repo;
  final int stars;
  final String? language;
  final String? error;

  factory PostingRepo.fromJson(Map<String, dynamic> json) {
    return PostingRepo(
      repo: json['repo'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      language: json['language'] as String?,
      error: json['error'] as String?,
    );
  }
}

class RolePosting {
  const RolePosting({
    required this.id,
    required this.postingType,
    required this.roleDesc,
    required this.skills,
    required this.status,
    required this.owner,
    this.projectId,
    this.projectTitle,
    this.stage,
    this.techStack,
    this.commitment,
    this.accessTier,
    this.repos = const [],
    this.createdAt,
  });

  final String id;

  /// maintainer | team_role
  final String postingType;
  final String roleDesc;
  final List<String> skills;

  /// open | closed
  final String status;
  final UserLite owner;
  final String? projectId;
  final String? projectTitle;
  final String? stage;
  final String? techStack;
  final String? commitment;
  final String? accessTier;
  final List<PostingRepo> repos;
  final DateTime? createdAt;

  bool get isMaintainer => postingType == 'maintainer';

  factory RolePosting.fromJson(Map<String, dynamic> json) {
    return RolePosting(
      id: json['id'] as String? ?? '',
      postingType: json['posting_type'] as String? ?? 'team_role',
      roleDesc: json['role_desc'] as String? ?? '',
      skills: (json['skills'] as List<dynamic>? ?? const [])
          .map((skill) => skill.toString())
          .toList(),
      status: json['status'] as String? ?? 'open',
      owner: json['owner'] is Map<String, dynamic>
          ? UserLite.fromJson(json['owner'] as Map<String, dynamic>)
          : const UserLite(id: '', githubLogin: '', primaryRole: 'builder'),
      projectId: json['project_id'] as String?,
      projectTitle: json['project_title'] as String?,
      stage: json['stage'] as String?,
      techStack: json['tech_stack'] as String?,
      commitment: json['commitment'] as String?,
      accessTier: json['access_tier'] as String?,
      repos: (json['repos'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PostingRepo.fromJson)
          .toList(),
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
