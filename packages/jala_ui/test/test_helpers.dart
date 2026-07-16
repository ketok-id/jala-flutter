import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';

/// Call once from test `setUpAll` so filter TextFields don't keep a
/// blinking cursor animation alive (which makes [WidgetTester.pumpAndSettle]
/// hang forever).
void configureJalaUiTests() {
  EditableText.debugDeterministicCursor = true;
}

/// Initializes a fresh, enabled [JalaBinding] for a test.
///
/// Pair with `tearDown(JalaBinding.resetForTesting)` so each test starts
/// from a clean binding.
JalaBinding initJalaBinding({int maxEntries = 300}) {
  return JalaBinding.instance
    ..initialize(config: JalaConfig(enabled: true, maxEntries: maxEntries));
}

/// Emits a request immediately followed by a response for [id] onto [bus],
/// producing one completed [NetworkCallEntry] in the store.
void emitCompletedCall(
  JalaEventBus bus,
  String id, {
  String method = 'GET',
  String url = 'https://api.example.com/users',
  Map<String, String> requestHeaders = const <String, String>{},
  CapturedBody? requestBody,
  int statusCode = 200,
  String? statusMessage = 'OK',
  Map<String, String> responseHeaders = const <String, String>{
    'content-type': 'application/json',
  },
  CapturedBody? responseBody,
  Duration duration = const Duration(milliseconds: 42),
  int? responseSize = 128,
  String? replayOf,
}) {
  bus
    ..emit(
      NetworkRequestEvent(
        callId: id,
        timestamp: DateTime.utc(2026, 7, 15, 12),
        method: method,
        uri: Uri.parse(url),
        headers: requestHeaders,
        body: requestBody ?? CapturedBody.none,
        client: 'test',
        replayOf: replayOf,
      ),
    )
    ..emit(
      NetworkResponseEvent(
        callId: id,
        timestamp: DateTime.utc(2026, 7, 15, 12, 0, 1),
        statusCode: statusCode,
        statusMessage: statusMessage,
        headers: responseHeaders,
        body: responseBody ?? CapturedBody.none,
        size: responseSize,
        duration: duration,
      ),
    );
}

/// Emits a request event for [id] on [bus] without a matching response,
/// producing a pending [NetworkCallEntry] — useful for exercising pending-
/// state UI (spinners, progress bars).
void emitPendingRequest(
  JalaEventBus bus,
  String id, {
  String method = 'GET',
  String url = 'https://api.example.com/download',
  Map<String, String> requestHeaders = const <String, String>{},
  CapturedBody? requestBody,
}) {
  bus.emit(
    NetworkRequestEvent(
      callId: id,
      timestamp: DateTime.utc(2026, 7, 15, 12),
      method: method,
      uri: Uri.parse(url),
      headers: requestHeaders,
      body: requestBody ?? CapturedBody.none,
      client: 'test',
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

/// Yields a single microtask so any sync-scheduled follow-ups from
/// [emitCompletedCall] land before a widget tree is pumped.
///
/// Must NOT use [Future.delayed]: under the widget-test fake-async zone a
/// timer never fires until [WidgetTester.pump], so `await Future.delayed`
/// hangs forever.
Future<void> flush() => Future<void>.microtask(() {});

/// Pumps [home] inside a real [MaterialApp] (and thus a real [Navigator]),
/// matching how Jala screens are expected to be embedded.
Future<void> pumpJalaApp(WidgetTester tester, Widget home) {
  return tester.pumpWidget(MaterialApp(home: home));
}

/// Bounded settle helper for screens that may host continuous animations
/// (progress indicators, cursors). Prefer this over raw [pumpAndSettle]
/// when a filter bar or pending spinner is in the tree.
Future<void> pumpJalaSettle(
  WidgetTester tester, {
  Duration step = const Duration(milliseconds: 16),
  int maxFrames = 40,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
  }
}
