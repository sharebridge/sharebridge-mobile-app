/// Typed exceptions raised by the donor setup API client.
///
/// These give the UI a stable surface area to discriminate between
/// recoverable conditions (timeouts, transient network blips), client
/// mistakes (4xx), upstream failures (5xx), and unexpected payloads.
sealed class DonorSetupApiException implements Exception {
  const DonorSetupApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised when the device cannot reach the API at all (DNS, refused, etc.).
class DonorSetupNetworkException extends DonorSetupApiException {
  const DonorSetupNetworkException(super.message);
}

/// Raised when the request exceeded the configured timeout.
class DonorSetupTimeoutException extends DonorSetupApiException {
  const DonorSetupTimeoutException(super.message);
}

/// Raised for HTTP 4xx responses (request was understood and rejected).
class DonorSetupBadRequestException extends DonorSetupApiException {
  const DonorSetupBadRequestException({
    required this.statusCode,
    required this.errorCode,
    required String message,
  }) : super(message);

  final int statusCode;
  final String? errorCode;
}

/// Raised for HTTP 5xx responses after retries have been exhausted.
class DonorSetupServerException extends DonorSetupApiException {
  const DonorSetupServerException({
    required this.statusCode,
    required String message,
  }) : super(message);

  final int statusCode;
}

/// Raised when the server returned a 2xx but the body was unparseable
/// or did not match the expected schema.
class DonorSetupResponseException extends DonorSetupApiException {
  const DonorSetupResponseException(super.message);
}
