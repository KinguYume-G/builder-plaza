/// Base URL of the Builder Plaza backend API.
///
/// Overridable at build/run time with:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);
