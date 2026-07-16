import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(configureJalaUiTests);
  tearDown(JalaBinding.resetForTesting);

  Future<void> pumpIndicator(WidgetTester tester, NetworkCallEntry entry) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: JalaStatusIndicator(entry: entry)),
      ),
    );
  }

  NetworkCallEntry pendingEntry({NetworkProgressEvent? progress}) {
    return NetworkCallEntry(
      id: 'x',
      startTime: DateTime.utc(2026, 7, 15, 12),
      method: 'GET',
      uri: Uri.parse('https://api.example.com/download'),
      requestHeaders: const <String, String>{},
      requestBody: CapturedBody.none,
      responseHeaders: const <String, String>{},
      responseBody: CapturedBody.none,
      status: JalaCallStatus.pending,
      client: 'test',
      progress: progress,
    );
  }

  testWidgets(
    'a pending entry with no progress shows the indeterminate spinner',
    (WidgetTester tester) async {
      await pumpIndicator(tester, pendingEntry());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'a pending entry with progress but no known total keeps the spinner',
    (WidgetTester tester) async {
      await pumpIndicator(
        tester,
        pendingEntry(
          progress: NetworkProgressEvent(
            callId: 'x',
            timestamp: DateTime.utc(2026),
            sentBytes: 10,
            receivedBytes: 0,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'a pending entry with a known total shows a determinate progress bar',
    (WidgetTester tester) async {
      await pumpIndicator(
        tester,
        pendingEntry(
          progress: NetworkProgressEvent(
            callId: 'x',
            timestamp: DateTime.utc(2026),
            sentBytes: 0,
            receivedBytes: 512,
            receivedTotal: 2048,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final LinearProgressIndicator bar = tester.widget(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.25, 0.001));
    },
  );

  testWidgets('a completed entry shows the plain status dot', (
    WidgetTester tester,
  ) async {
    await pumpIndicator(
      tester,
      pendingEntry().copyWith(status: JalaCallStatus.success, statusCode: 200),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
