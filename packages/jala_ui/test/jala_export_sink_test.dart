// Regression tests for the export path, which used to await
// `Clipboard.setData` with no try/catch and then show a "copied" snackbar
// unconditionally — so an oversized payload (routine on Android, where the
// clipboard rides a ~1 MB Binder buffer) reported success while delivering
// nothing.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala_core/jala_core.dart';
import 'package:jala_ui/jala_ui.dart';

import 'test_helpers.dart';

/// A sink that always fails, standing in for an Android clipboard rejecting
/// an oversized payload.
class _FailingSink extends JalaExportSink {
  const _FailingSink();

  @override
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  }) async => JalaExportOutcome(
    ok: false,
    bytes: payload.length,
    destination: 'clipboard',
    error: PlatformException(code: 'TransactionTooLargeException'),
  );
}

/// Records what it was handed.
class _RecordingSink extends JalaExportSink {
  _RecordingSink();

  String? payload;
  String? fileName;

  @override
  Future<JalaExportOutcome> deliver({
    required String payload,
    required String fileName,
  }) async {
    this.payload = payload;
    this.fileName = fileName;
    return JalaExportOutcome(
      ok: true,
      bytes: payload.length,
      destination: '/tmp/$fileName',
    );
  }
}

void main() {
  setUpAll(configureJalaUiTests);

  tearDown(() async {
    JalaExportSink.install(null);
    await JalaBinding.resetForTesting();
  });

  Future<void> pumpInspector(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: JalaInspectorScreen()),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openExportMenu(WidgetTester tester, String item) async {
    await pumpInspector(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed export reports failure, not success', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'c1');
    await tester.pump();
    JalaExportSink.install(const _FailingSink());

    await openExportMenu(tester, 'Export session (full)');

    expect(
      find.textContaining('Export failed'),
      findsOneWidget,
      reason: 'a clipboard rejection must surface — it used to report '
          '"copied" regardless',
    );
    expect(find.textContaining('entries copied'), findsNothing);
  });

  testWidgets('a successful export names its destination and size', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'c1');
    await tester.pump();
    final _RecordingSink sink = _RecordingSink();
    JalaExportSink.install(sink);

    await openExportMenu(tester, 'Export session (full)');

    expect(sink.fileName, 'jala_session.json');
    expect(sink.payload, isNotNull);
    expect(find.textContaining('/tmp/jala_session.json'), findsOneWidget);
  });

  testWidgets('HAR export routes through the sink too', (
    WidgetTester tester,
  ) async {
    final JalaBinding binding = initJalaBinding();
    emitCompletedCall(binding.bus, 'c1');
    await tester.pump();
    final _RecordingSink sink = _RecordingSink();
    JalaExportSink.install(sink);

    await pumpInspector(tester);
    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(sink.fileName, 'jala_session.har');
    expect(sink.payload, contains('"log"'));
  });

  group('JalaExportOutcome', () {
    test('flags payloads large enough for the clipboard to drop', () {
      const JalaExportOutcome small = JalaExportOutcome(
        ok: true,
        bytes: 1024,
        destination: 'clipboard',
      );
      const JalaExportOutcome big = JalaExportOutcome(
        ok: true,
        bytes: 2 * 1024 * 1024,
        destination: 'clipboard',
      );
      expect(small.isRisky, isFalse);
      expect(big.isRisky, isTrue);
      expect(small.sizeLabel, '1.0 KB');
      expect(big.sizeLabel, '2.0 MB');
    });
  });
}
