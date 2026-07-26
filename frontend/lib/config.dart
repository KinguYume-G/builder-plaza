/// Base URL of the Builder Plaza backend API.
///
/// Defaults to the deployed ECS Fargate backend (see docs/DEPLOYMENT.md) so a
/// plain `flutter run` works with zero
/// configuration. Override for local backend development with:
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com',
);
