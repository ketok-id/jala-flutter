/// Lifecycle status of a captured network call.
enum KetokCallStatus {
  /// Request has been sent; no response, error, or cancellation yet.
  pending,

  /// A response was received (regardless of HTTP status code — a 404 is
  /// still a "successful" round trip at the transport level).
  success,

  /// The call failed at the transport/client level (exception, timeout,
  /// connection error, etc.), as opposed to merely receiving a non-2xx
  /// response.
  error,

  /// The call was cancelled before it completed.
  cancelled,
}
