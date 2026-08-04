import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_example/main.dart';

void main() {
  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  testWidgets('example app renders QA buttons', (WidgetTester tester) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    expect(find.text('Jala QA Rig'), findsOneWidget);
    expect(find.text('GET json'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('Inspect deeper sample buttons import HAR and open compare', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Import HAR (sample)'),
      200,
    );
    await tester.tap(find.text('Import HAR (sample)'));
    await tester.pumpAndSettle();

    expect(JalaBinding.instance.store.entries, hasLength(2));
    expect(JalaBinding.instance.store.isViewingImport, isTrue);
    expect(find.textContaining('Imported HAR'), findsOneWidget);

    // Dismiss the snackbar so it does not steal the next tap.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
      tester.element(find.text('Jala QA Rig')),
    );
    messenger.hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Compare last two'), 100);
    await tester.tap(find.text('Compare last two'));
    await tester.pumpAndSettle();

    expect(find.byType(JalaCallDiffScreen), findsOneWidget);
    expect(find.text('Compare calls'), findsOneWidget);
  });

  testWidgets('Import cURL sample opens the request composer', (
    WidgetTester tester,
  ) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('Import cURL (sample)'),
      200,
    );
    await tester.tap(find.text('Import cURL (sample)'));
    await tester.pumpAndSettle();

    expect(find.byType(JalaRequestComposerScreen), findsOneWidget);
    expect(find.textContaining('api.example.com/orders'), findsWidgets);
  });

  group('gRPC panel (Track G G4)', () {
    Future<void> tapGrpc(WidgetTester tester, String label) async {
      Jala.initialize(config: JalaConfig(enabled: true));
      await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: Dio())));
      await tester.pump();

      await tester.scrollUntilVisible(find.text(label), 200);
      // scrollUntilVisible stops as soon as the widget exists; the gRPC
      // panel is the last section, so the button can still be below the
      // fold and untappable.
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    testWidgets('a unary RPC captures both messages and its trailers', (
      WidgetTester tester,
    ) async {
      await tapGrpc(tester, 'gRPC unary (OK)');

      final NetworkCallEntry entry =
          JalaBinding.instance.store.entries.single;
      expect(entry.client, 'grpc');
      expect(entry.rpcKind, 'unary');
      expect(entry.operationName, 'GetFeature');
      expect(entry.grpcStatusCode, 0);
      expect(entry.trailers['grpc-status'], '0');
      expect(entry.requestBody.text, contains('latitude'));
      expect(entry.responseBody.text, contains('Berkshire'));
    });

    testWidgets('a failed RPC records its gRPC status, not just HTTP 200', (
      WidgetTester tester,
    ) async {
      await tapGrpc(tester, 'gRPC unary (NOT_FOUND)');

      final NetworkCallEntry entry =
          JalaBinding.instance.store.entries.single;
      expect(entry.status, JalaCallStatus.error);
      expect(entry.grpcStatusCode, 5);
      expect(entry.errorMessage, contains('NOT_FOUND'));
    });

    testWidgets('proto3-JSON messages are redacted at capture time', (
      WidgetTester tester,
    ) async {
      await tapGrpc(tester, 'gRPC unary (redaction check)');

      final NetworkCallEntry entry =
          JalaBinding.instance.store.entries.single;
      expect(entry.requestBody.text, isNot(contains('hunter2')));
      expect(entry.responseBody.text, isNot(contains('eyJhbGciOi')));
      expect(entry.requestBody.text, contains(JalaRedactor.mask));
    });

    testWidgets('a streaming RPC records its envelope but no messages', (
      WidgetTester tester,
    ) async {
      await tapGrpc(tester, 'gRPC streaming (RouteChat)');

      final NetworkCallEntry entry =
          JalaBinding.instance.store.entries.single;
      expect(entry.rpcKind, 'bidi');
      expect(entry.operationName, 'RouteChat');
      expect(entry.trailers['grpc-status'], '0');
      // Documented limitation, surfaced by the detail screen's note.
      expect(entry.responseBody.kind, BodyKind.none);
      expect(entry.progress?.sentBytes, greaterThan(0));
    });
  });
}
