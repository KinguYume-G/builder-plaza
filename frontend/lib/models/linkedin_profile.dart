/// A simulated LinkedIn profile offered during the (demo) consent step.
///
/// NOTE: These profiles are entirely SIMULATED for the academic demo — they do
/// not come from the real LinkedIn API. See the onboarding consent screen.
///
/// Matches the backend JSON contract:
/// ```json
/// { "id": String, "sub": String, "name": String, "headline": String,
///   "company": String, "title": String, "tenure_years": num,
///   "picture": String? }
/// ```
class LinkedInProfile {
  const LinkedInProfile({
    required this.id,
    required this.sub,
    required this.name,
    required this.headline,
    required this.company,
    required this.title,
    required this.tenureYears,
    this.picture,
  });

  final String id;
  final String sub;
  final String name;
  final String headline;
  final String company;
  final String title;
  final double tenureYears;
  final String? picture;

  factory LinkedInProfile.fromJson(Map<String, dynamic> json) {
    return LinkedInProfile(
      id: json['id'] as String? ?? '',
      sub: json['sub'] as String? ?? '',
      name: json['name'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      company: json['company'] as String? ?? '',
      title: json['title'] as String? ?? '',
      tenureYears: (json['tenure_years'] as num?)?.toDouble() ?? 0,
      picture: json['picture'] as String?,
    );
  }
}
