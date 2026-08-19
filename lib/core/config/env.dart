abstract final class AppEnvironment {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.hanul-on.cloud',
  );

  static const initialLocation = String.fromEnvironment(
    'INITIAL_ROUTE',
    defaultValue: '/',
  );
}
