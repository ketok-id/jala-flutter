/// gRPC binding for Jala, the in-app Flutter network inspector.
///
/// A `package:grpc` `ClientInterceptor` that captures unary and streaming
/// RPCs — service/method, messages, metadata, status codes and trailers —
/// into the shared Jala store. Capture only: mocking and throttling do not
/// apply to gRPC (see [JalaGrpcInterceptor] for why).
library;

export 'src/jala_grpc_interceptor.dart';
