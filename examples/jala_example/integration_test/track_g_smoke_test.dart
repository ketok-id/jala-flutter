// Track G smoke on a real device/simulator: the gRPC panel from the QA rig.
// No live network required — the RPCs run over a canned in-memory
// ClientCall, so this passes offline. Prints step markers for hang
// diagnosis.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_example/main.dart' as app;

void step(String msg) {
  // ignore: avoid_print
  print('TRACK_G_SMOKE: $msg');
}

Future<void> pause(WidgetTester tester, int ms) async {
  await tester.pump();
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  // scrollUntilVisible stops as soon as the widget exists; the gRPC panel is
  // the last section, so it can still be below the fold.
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await pause(tester, 400);
}

NetworkCallEntry entryFor(String operationName) {
  return JalaBinding.instance.store.entries.firstWhere(
    (NetworkCallEntry e) => e.operationName == operationName,
    orElse: () => throw StateError('no captured RPC named $operationName'),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('G4 gRPC panel captures unary, error, redaction, streaming', (
    WidgetTester tester,
  ) async {
    step('1 launch app');
    unawaited(app.main());
    await tester.pumpAndSettle();
    await pause(tester, 800);

    expect(find.text('Jala QA Rig'), findsOneWidget);

    // --- Unary OK: both messages captured, trailers present ---
    step('2 gRPC unary (OK)');
    await tapButton(tester, 'gRPC unary (OK)');

    final NetworkCallEntry ok = entryFor('GetFeature');
    expect(ok.client, 'grpc');
    expect(ok.rpcKind, 'unary');
    expect(ok.grpcStatusCode, 0);
    expect(ok.trailers['grpc-status'], '0');
    expect(ok.requestBody.text, contains('latitude'));
    expect(ok.responseBody.text, contains('Berkshire'));
    step('   unary OK captured: ${ok.responseBody.text}');

    // --- Metadata redaction on a real device ---
    expect(ok.requestHeaders['authorization'], JalaRedactor.mask);
    step('   authorization masked');

    // --- Unary NOT_FOUND: a failed RPC over an HTTP 200 ---
    step('3 gRPC unary (NOT_FOUND)');
    await tapButton(tester, 'gRPC unary (NOT_FOUND)');
    await pause(tester, 400);

    final NetworkCallEntry failed = JalaBinding.instance.store.entries
        .firstWhere((NetworkCallEntry e) => e.grpcStatusCode == 5);
    expect(failed.status, JalaCallStatus.error);
    expect(failed.errorMessage, contains('NOT_FOUND'));
    step('   NOT_FOUND captured: ${failed.errorMessage}');

    // --- Redaction of a proto3-JSON message body ---
    step('4 gRPC unary (redaction check)');
    await tapButton(tester, 'gRPC unary (redaction check)');

    final NetworkCallEntry login = entryFor('Login');
    expect(login.requestBody.text, isNot(contains('hunter2')));
    expect(login.requestBody.text, contains(JalaRedactor.mask));
    expect(login.responseBody.text, isNot(contains('eyJhbGciOi')));
    step('   redacted request: ${login.requestBody.text}');
    step('   redacted response: ${login.responseBody.text}');

    // --- Streaming: envelope captured, response messages deliberately not ---
    step('5 gRPC streaming (RouteChat)');
    await tapButton(tester, 'gRPC streaming (RouteChat)');

    final NetworkCallEntry chat = entryFor('RouteChat');
    expect(chat.rpcKind, 'bidi');
    expect(chat.trailers['grpc-status'], '0');
    expect(chat.responseBody.kind, BodyKind.none);
    expect(chat.progress?.sentBytes ?? 0, greaterThan(0));
    step('   streaming envelope captured, sent=${chat.progress?.sentBytes}B');

    // --- The inspector renders all four ---
    step('6 open inspector and filter to gRPC');
    Jala.open();
    await tester.pumpAndSettle();
    await pause(tester, 600);

    expect(find.text('routeguide.RouteGuide/GetFeature'), findsWidgets);
    expect(find.text('NOT_FOUND'), findsWidgets);
    step('   gRPC tiles rendered with status names');

    Jala.close();
    await tester.pumpAndSettle();
    step('7 done');
  });
}
