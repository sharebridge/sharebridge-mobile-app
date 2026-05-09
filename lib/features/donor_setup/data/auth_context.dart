/// Auth context for MVP signed-token flow.
///
/// `authToken` is expected from `--dart-define=AUTH_TOKEN=...`, issued by
/// sharebridge-user-service (`POST /v1/auth/token`).
///
/// `userId` remains sourced from `--dart-define=USER_ID=...` for request
/// payload fields and local display/state.
class AuthContext {
  const AuthContext({required this.userId, required this.authToken});

  /// Builds the AuthContext from compile-time defines. The default keeps
  /// existing local-dev behavior backward compatible.
  factory AuthContext.fromEnvironment() {
    const userId = String.fromEnvironment(
      'USER_ID',
      defaultValue: 'demo-user',
    );
    const authToken = String.fromEnvironment('AUTH_TOKEN', defaultValue: '');
    return const AuthContext(userId: userId, authToken: authToken);
  }

  final String userId;
  final String authToken;

  String get bearerToken => authToken.trim();

  Map<String, String> toHeaders() {
    if (bearerToken.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{
      'authorization': 'Bearer $bearerToken',
    };
  }
}
