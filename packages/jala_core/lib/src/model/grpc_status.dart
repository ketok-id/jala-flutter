/// Canonical gRPC status codes and their names.
///
/// Lives in `jala_core` rather than `jala_grpc` because both sides need it
/// and they cannot see each other: `jala_ui` renders the status name on a
/// call tile, `jala_grpc` builds the error message, and adapters never
/// depend on the UI (nor it on them).
class JalaGrpcStatus {
  const JalaGrpcStatus._();

  /// `0` — the RPC completed successfully.
  static const int ok = 0;

  /// Canonical name for [code] (`5` -> `NOT_FOUND`).
  ///
  /// An unrecognized code renders as `CODE_<n>` rather than throwing: the
  /// inspector has to display whatever the server actually sent, including
  /// codes from a newer gRPC revision than this build knows about.
  static String nameOf(int code) =>
      code >= 0 && code < _names.length ? _names[code] : 'CODE_$code';

  /// Whether [code] represents a failed RPC.
  static bool isError(int code) => code != ok;

  static const List<String> _names = <String>[
    'OK',
    'CANCELLED',
    'UNKNOWN',
    'INVALID_ARGUMENT',
    'DEADLINE_EXCEEDED',
    'NOT_FOUND',
    'ALREADY_EXISTS',
    'PERMISSION_DENIED',
    'RESOURCE_EXHAUSTED',
    'FAILED_PRECONDITION',
    'ABORTED',
    'OUT_OF_RANGE',
    'UNIMPLEMENTED',
    'INTERNAL',
    'UNAVAILABLE',
    'DATA_LOSS',
    'UNAUTHENTICATED',
  ];
}
