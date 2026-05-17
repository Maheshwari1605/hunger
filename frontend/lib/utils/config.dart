/// Override at build time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
/// (10.0.2.2 is the Android emulator's host loopback.)
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
}
