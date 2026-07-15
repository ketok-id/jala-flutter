import 'package:ketok_core/ketok_core.dart';

/// Builds a [NetworkCallEntry] with sensible defaults for tests.
NetworkCallEntry makeEntry({
  String id = 'call-1',
  DateTime? startTime,
  String method = 'GET',
  String url = 'https://api.example.com/users?page=1',
  Map<String, String> requestHeaders = const <String, String>{},
  CapturedBody? requestBody,
  int? statusCode = 200,
  String? statusMessage = 'OK',
  Map<String, String> responseHeaders = const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
  CapturedBody? responseBody,
  Duration? duration = const Duration(milliseconds: 120),
  int? requestSize,
  int? responseSize = 256,
  KetokCallStatus status = KetokCallStatus.success,
  String? errorMessage,
  String? replayOf,
  String client = 'dio',
}) {
  return NetworkCallEntry(
    id: id,
    startTime: startTime ?? DateTime.utc(2026, 7, 15, 12),
    method: method,
    uri: Uri.parse(url),
    requestHeaders: requestHeaders,
    requestBody: requestBody ?? CapturedBody.none,
    statusCode: statusCode,
    statusMessage: statusMessage,
    responseHeaders: responseHeaders,
    responseBody: responseBody ?? CapturedBody.none,
    duration: duration,
    requestSize: requestSize,
    responseSize: responseSize,
    status: status,
    errorMessage: errorMessage,
    replayOf: replayOf,
    client: client,
  );
}

/// Flushes pending microtasks/timers so async stream deliveries settle.
Future<void> pump() => Future<void>.delayed(Duration.zero);

/// A bus that is always enabled, for store tests.
KetokEventBus enabledBus() => KetokEventBus(isEnabled: () => true);

/// Emits a request event for [id] on [bus].
void emitRequest(
  KetokEventBus bus,
  String id, {
  String method = 'GET',
  String url = 'https://api.example.com/users',
  Map<String, String> headers = const <String, String>{},
  CapturedBody? body,
  int? size,
  String client = 'dio',
  String? replayOf,
}) {
  bus.emit(
    NetworkRequestEvent(
      callId: id,
      timestamp: DateTime.utc(2026, 7, 15, 12),
      method: method,
      uri: Uri.parse(url),
      headers: headers,
      body: body ?? CapturedBody.none,
      size: size,
      client: client,
      replayOf: replayOf,
    ),
  );
}

/// Emits a response event for [id] on [bus].
void emitResponse(
  KetokEventBus bus,
  String id, {
  int statusCode = 200,
  String? statusMessage = 'OK',
  Map<String, String> headers = const <String, String>{
    'content-type': 'application/json',
  },
  CapturedBody? body,
  int? size,
  Duration duration = const Duration(milliseconds: 50),
}) {
  bus.emit(
    NetworkResponseEvent(
      callId: id,
      timestamp: DateTime.utc(2026, 7, 15, 12, 0, 1),
      statusCode: statusCode,
      statusMessage: statusMessage,
      headers: headers,
      body: body ?? CapturedBody.none,
      size: size,
      duration: duration,
    ),
  );
}
