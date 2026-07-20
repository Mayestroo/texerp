/// Network / API failure carrying the server error code and a message.
class NetworkException implements Exception {
  const NetworkException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'NetworkException(code: $code, message: $message)';
}
