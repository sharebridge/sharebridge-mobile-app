/// Minimal auth context for MVP.
///
/// Until sharebridge-user-service ships real auth, the mobile app carries a
/// non-cryptographic placeholder identity. The integration-service accepts
/// this in two header forms:
///
///   Authorization: Bearer demo.<user_id>
///   X-User-Id: <user_id>
///
/// `userId` is sourced from `--dart-define=USER_ID=...` at build time, with
/// a `'demo-user'` fallback so local dev keeps working.
class AuthContext {
  const AuthContext({required this.userId});

  /// Builds the AuthContext from compile-time defines. The default keeps
  /// existing local-dev behavior backward compatible.
  factory AuthContext.fromEnvironment() {
    const userId = String.fromEnvironment(
      'USER_ID',
      defaultValue: 'demo-user',
    );
    return const AuthContext(userId: userId);
  }

  final String userId;

  /// MVP placeholder token. Not cryptographically signed; the
  /// integration-service trusts it for local dev only.
  String get bearerToken => 'demo.$userId';

  Map<String, String> toHeaders() {
    return <String, String>{
      'authorization': 'Bearer $bearerToken',
      'x-user-id': userId,
    };
  }
}
