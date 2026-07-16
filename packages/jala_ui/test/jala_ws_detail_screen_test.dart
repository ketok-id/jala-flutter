import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  testWidgets(
    'renders the connection header and frame timeline, live-updating as '
    'new frames arrive',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitWsConnect(
        binding.bus,
        'ws-1',
        url: 'wss://echo.example.com/socket',
        timestamp: DateTime.utc(2026, 7, 15, 12),
      );
      emitWsFrame(
        binding.bus,
        'ws-1',
        data: 'ping',
        timestamp: DateTime.utc(2026, 7, 15, 12, 0, 1),
      );
      emitWsFrame(
        binding.bus,
        'ws-1',
        direction: WsDirection.received,
        data: 'pong',
        timestamp: DateTime.utc(2026, 7, 15, 12, 0, 1, 500),
      );
      await flush();

      await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
      await pumpJalaSettle(tester);

      expect(find.text('wss://echo.example.com/socket'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('ping'), findsOneWidget);
      expect(find.text('pong'), findsOneWidget);
      expect(find.text('↑'), findsOneWidget);
      expect(find.text('↓'), findsOneWidget);
      expect(find.text('+1.00s'), findsOneWidget);
      expect(find.text('+1.50s'), findsOneWidget);
      // Frame count row (header). Sizes: 4 B each.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4 B'), findsNWidgets(2));
      // No HTTP-only export/replay actions on a WS connection.
      expect(find.text('cURL'), findsNothing);
      expect(find.text('HAR'), findsNothing);
      expect(find.text('Dart'), findsNothing);
      expect(find.text('Replay'), findsNothing);

      emitWsFrame(
        binding.bus,
        'ws-1',
        data: 'again',
        timestamp: DateTime.utc(2026, 7, 15, 12, 0, 2),
      );
      await flush();
      await pumpJalaSettle(tester);

      expect(find.text('again'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets('shows close code and reason once the connection closes', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    await flush();

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);
    expect(find.text('Close code'), findsNothing);

    emitWsClose(binding.bus, 'ws-1', code: 1000, reason: 'normal closure');
    await flush();
    await pumpJalaSettle(tester);

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Closed at'), findsOneWidget);
    expect(find.text('Close code'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('normal closure'), findsOneWidget);
  });

  testWidgets('a binary frame renders as metadata only', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    emitWsFrame(binding.bus, 'ws-1', data: <int>[1, 2, 3, 4, 5]);
    await flush();

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);

    expect(find.text('binary — 5 bytes'), findsOneWidget);
  });

  testWidgets('notes when the ring buffer trimmed older frames '
      '(frameCount > frames.length)', (WidgetTester tester) async {
    final JalaBinding binding = initJalaBinding(maxWsFramesPerConnection: 2);
    emitWsConnect(binding.bus, 'ws-1');
    emitWsFrame(binding.bus, 'ws-1', data: 'one');
    emitWsFrame(binding.bus, 'ws-1', data: 'two');
    emitWsFrame(binding.bus, 'ws-1', data: 'three');
    await flush();

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);

    expect(find.text('3 (showing last 2)'), findsOneWidget);
    expect(find.text('one'), findsNothing);
    expect(find.text('two'), findsOneWidget);
    expect(find.text('three'), findsOneWidget);
  });

  testWidgets(
    'tapping a JSON text frame opens a preview sheet with the JSON tree',
    (WidgetTester tester) async {
      final JalaBinding binding = initJalaBinding();
      emitWsConnect(binding.bus, 'ws-1');
      emitWsFrame(binding.bus, 'ws-1', data: '{"greeting":"hi"}');
      await flush();

      await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
      await pumpJalaSettle(tester);
      expect(find.byType(JalaJsonTree), findsNothing);

      await tester.tap(find.text('{"greeting":"hi"}'));
      await pumpJalaSettle(tester);

      expect(find.text('Frame preview'), findsOneWidget);
      expect(find.byType(JalaJsonTree), findsOneWidget);
      // Root map is expanded by default, so the leaf is visible.
      expect(find.textContaining('greeting: hi'), findsOneWidget);
    },
  );

  testWidgets('tapping a non-JSON text frame shows selectable monospace text', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    emitWsFrame(binding.bus, 'ws-1', data: 'plain text frame');
    await flush();

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);

    await tester.tap(find.text('plain text frame'));
    await pumpJalaSettle(tester);

    expect(find.text('Frame preview'), findsOneWidget);
    expect(find.byType(JalaJsonTree), findsNothing);
    // Tile title + sheet body.
    expect(find.text('plain text frame'), findsNWidgets(2));
  });

  testWidgets('the frame filter narrows the timeline by preview substring', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    emitWsFrame(binding.bus, 'ws-1', data: 'alpha message');
    emitWsFrame(binding.bus, 'ws-1', data: 'beta message');
    await flush();

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);
    expect(find.text('alpha message'), findsOneWidget);
    expect(find.text('beta message'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'beta');
    await pumpJalaSettle(tester);

    expect(find.text('alpha message'), findsNothing);
    expect(find.text('beta message'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'no-such-frame');
    await pumpJalaSettle(tester);

    expect(find.textContaining('No frames match'), findsOneWidget);
  });

  testWidgets('Copy connection summary puts a JSON summary on the clipboard', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1', url: 'wss://echo.example.com/socket');
    emitWsFrame(binding.bus, 'ws-1', data: 'ping');
    emitWsClose(binding.bus, 'ws-1', code: 1000, reason: 'done');
    await flush();

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);

    await tester.tap(find.byTooltip('Copy connection summary'));
    await pumpJalaSettle(tester);

    expect(clipboardText, isNotNull);
    final Map<String, dynamic> summary =
        jsonDecode(clipboardText!) as Map<String, dynamic>;
    expect(summary['uri'], 'wss://echo.example.com/socket');
    expect(summary['status'], 'closed');
    expect(summary['closeCode'], 1000);
    expect(summary['closeReason'], 'done');
    expect(summary['frameCount'], 1);
    final List<dynamic> frames = summary['frames'] as List<dynamic>;
    expect(frames, hasLength(1));
    final Map<String, dynamic> frame = frames[0] as Map<String, dynamic>;
    expect(frame['direction'], 'sent');
    expect(frame['isBinary'], false);
    expect(frame['size'], 4);
    expect(find.text('Copied connection summary'), findsOneWidget);
  });

  testWidgets('long-pressing a text frame copies its preview', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitWsConnect(binding.bus, 'ws-1');
    emitWsFrame(binding.bus, 'ws-1', data: 'copy me');
    await flush();

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          final Map<Object?, Object?> args =
              call.arguments as Map<Object?, Object?>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpJalaApp(tester, const JalaWsDetailScreen(connectionId: 'ws-1'));
    await pumpJalaSettle(tester);

    await tester.longPress(find.text('copy me'));
    await pumpJalaSettle(tester);

    expect(clipboardText, 'copy me');
  });

  testWidgets('shows a fallback when the connection is no longer available', (
    WidgetTester tester,
  ) async {
    initJalaBinding();

    await pumpJalaApp(
      tester,
      const JalaWsDetailScreen(connectionId: 'missing'),
    );
    await pumpJalaSettle(tester);

    expect(
      find.text('This connection is no longer available.'),
      findsOneWidget,
    );
  });
}
