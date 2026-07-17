/// In-memory holder for the current access token.
///
/// The access token is deliberately not persisted; the repository stores only
/// the refresh token in secure storage. This holder lets the Dio interceptors
/// read the latest token without importing the AuthBloc.
class TokenProvider {
  String? accessToken;
}
