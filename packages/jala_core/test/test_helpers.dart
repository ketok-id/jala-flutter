import 'package:jala_core/jala_core.dart';

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
  JalaCallStatus status = JalaCallStatus.success,
  String? errorMessage,
  String? replayOf,
  String? mockRuleId,
  String client = 'dio',
  NetworkProgressEvent? progress,
  String? operationName,
  String? operationType,
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
    mockRuleId: mockRuleId,
    client: client,
    progress: progress,
    operationName: operationName,
    operationType: operationType,
  );
}

/// Flushes pending microtasks/timers so async stream deliveries settle.
Future<void> pump() => Future<void>.delayed(Duration.zero);

/// A bus that is always enabled, for store tests.
JalaEventBus enabledBus() => JalaEventBus(isEnabled: () => true);

/// Emits a request event for [id] on [bus].
void emitRequest(
  JalaEventBus bus,
  String id, {
  String method = 'GET',
  String url = 'https://api.example.com/users',
  Map<String, String> headers = const <String, String>{},
  CapturedBody? body,
  int? size,
  String client = 'dio',
  String? replayOf,
  String? operationName,
  String? operationType,
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
      operationName: operationName,
      operationType: operationType,
    ),
  );
}

/// Emits a response event for [id] on [bus].
void emitResponse(
  JalaEventBus bus,
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

/// Emits a progress event for [id] on [bus].
void emitProgress(
  JalaEventBus bus,
  String id, {
  int sentBytes = 0,
  int? sentTotal,
  int receivedBytes = 0,
  int? receivedTotal,
}) {
  bus.emit(
    NetworkProgressEvent(
      callId: id,
      timestamp: DateTime.utc(2026, 7, 15, 12, 0, 0, 500),
      sentBytes: sentBytes,
      sentTotal: sentTotal,
      receivedBytes: receivedBytes,
      receivedTotal: receivedTotal,
    ),
  );
}

/// Builds a [WsConnectionEntry] with sensible defaults for tests.
WsConnectionEntry makeWsEntry({
  String id = 'ws-1',
  String url = 'wss://echo.example.com/socket',
  WsConnectionStatus status = WsConnectionStatus.open,
  DateTime? openedAt,
  DateTime? closedAt,
  int? closeCode,
  String? closeReason,
  int frameCount = 0,
  List<WsFrame> frames = const <WsFrame>[],
}) {
  return WsConnectionEntry(
    id: id,
    uri: Uri.parse(url),
    status: status,
    openedAt: openedAt ?? DateTime.utc(2026, 7, 15, 12),
    closedAt: closedAt,
    closeCode: closeCode,
    closeReason: closeReason,
    frameCount: frameCount,
    frames: frames,
  );
}

/// Emits a [WsConnectEvent] for [id] on [bus].
void emitWsConnect(
  JalaEventBus bus,
  String id, {
  String url = 'wss://echo.example.com/socket',
  DateTime? timestamp,
}) {
  bus.emit(
    WsConnectEvent(
      connectionId: id,
      timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12),
      uri: Uri.parse(url),
    ),
  );
}

/// Emits a [WsFrameEvent] for [id] on [bus].
void emitWsFrame(
  JalaEventBus bus,
  String id, {
  WsDirection direction = WsDirection.sent,
  dynamic data = 'hello',
  DateTime? timestamp,
  JalaRedactor? redactor,
}) {
  bus.emit(
    WsFrameEvent(
      connectionId: id,
      timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12, 0, 1),
      frame: WsFrame.capture(
        timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12, 0, 1),
        direction: direction,
        data: data,
        redactor: redactor ?? JalaRedactor(),
      ),
    ),
  );
}

/// Emits a [WsOpenEvent] for [id] on [bus].
void emitWsOpen(JalaEventBus bus, String id, {DateTime? timestamp}) {
  bus.emit(
    WsOpenEvent(
      connectionId: id,
      timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12, 0, 1),
    ),
  );
}

/// Emits a [WsCloseEvent] for [id] on [bus].
void emitWsClose(
  JalaEventBus bus,
  String id, {
  int? code,
  String? reason,
  DateTime? timestamp,
}) {
  bus.emit(
    WsCloseEvent(
      connectionId: id,
      timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12, 0, 2),
      code: code,
      reason: reason,
    ),
  );
}

/// Emits a [WsErrorEvent] for [id] on [bus].
void emitWsError(
  JalaEventBus bus,
  String id, {
  String errorMessage = 'connection reset',
  DateTime? timestamp,
}) {
  bus.emit(
    WsErrorEvent(
      connectionId: id,
      timestamp: timestamp ?? DateTime.utc(2026, 7, 15, 12, 0, 2),
      errorMessage: errorMessage,
    ),
  );
}
