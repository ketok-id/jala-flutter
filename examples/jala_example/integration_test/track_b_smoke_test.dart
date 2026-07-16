// Live smoke for Track B3/B4 on a real device/simulator.
//
// Fires real network calls through jala_dio / jala_http and asserts against
// Jala.store + the inspector UI.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';
import 'package:jala_example/main.dart' as app;
import 'package:jala_http/jala_http.dart';

Future<void> pause(WidgetTester tester, int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await tester.pump();
}

Future<void> openInspector(WidgetTester tester) async {
  final Finder bubble = find.text('J');
  expect(bubble, findsWidgets);
  await tester.tap(bubble.last);
  await pause(tester, 1200);
}

Future<void> closeInspector(WidgetTester tester) async {
  final Finder close = find.byTooltip('Close inspector');
  if (close.evaluate().isNotEmpty) {
    await tester.ensureVisible(close);
    await tester.tap(close, warnIfMissed: false);
    await pause(tester, 600);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('B3 multipart + B4 large download smoke', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await pause(tester, 500);

    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
    JalaDio.attach(dio);
    final http.Client httpClient = JalaHttp.wrap(http.Client());
    addTearDown(httpClient.close);

    final int beforeCount = Jala.store.entries.length;

    // --- B3: multipart via Dio FormData ---
    final FormData form = FormData.fromMap(<String, dynamic>{
      'field': 'jala',
      'file': MultipartFile.fromString(
        'hello from jala example',
        filename: 'hello.txt',
      ),
    });
    final Response<dynamic> mp = await dio.post<dynamic>(
      'https://postman-echo.com/post',
      data: form,
    );
    expect(mp.statusCode, 200);
    await pause(tester, 500);

    final NetworkCallEntry multipartEntry = Jala.store.entries.firstWhere(
      (NetworkCallEntry e) =>
          e.method == 'POST' && e.uri.host == 'postman-echo.com',
    );
    final List<JalaMultipartPart>? parts =
        CapturedBodyMultipart.partsOf(multipartEntry.requestBody);
    expect(parts, isNotNull, reason: 'request body should use @multipart');
    expect(parts!.map((JalaMultipartPart p) => p.name), contains('field'));
    expect(
      parts.map((JalaMultipartPart p) => p.filename).whereType<String>(),
      contains('hello.txt'),
    );

    // Inspector UI: multipart parts table on Request tab.
    await openInspector(tester);
    // List tiles show the path `/post`.
    final Finder postPath = find.text('/post');
    expect(postPath, findsWidgets);
    await tester.tap(postPath.first);
    await pause(tester, 900);
    await tester.tap(find.text('Request'));
    await pause(tester, 900);

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Filename'), findsOneWidget);
    expect(find.text('field'), findsWidgets);
    expect(find.text('hello.txt'), findsWidgets);

    // Pop detail route.
    final NavigatorState nav = tester.state<NavigatorState>(
      find.byType(Navigator).last,
    );
    nav.pop();
    await pause(tester, 500);
    await closeInspector(tester);

    // --- B4: large download via jala_http (tee + progress) ---
    final http.Response large = await httpClient.get(
      Uri.parse('https://speed.cloudflare.com/__down?bytes=1048576'),
    );
    expect(large.statusCode, 200);
    expect(large.bodyBytes.length, 1048576);
    await pause(tester, 600);

    final NetworkCallEntry largeEntry = Jala.store.entries.firstWhere(
      (NetworkCallEntry e) => e.uri.host == 'speed.cloudflare.com',
    );
    expect(largeEntry.status, isNot(JalaCallStatus.pending));
    expect(largeEntry.client, 'http');
    expect(
      largeEntry.progress,
      isNotNull,
      reason: 'download progress should be recorded on the entry',
    );
    expect(largeEntry.progress!.receivedBytes, greaterThan(0));

    await openInspector(tester);
    // List tile title is the path `/__down`.
    final Finder downPath = find.text('/__down');
    expect(downPath, findsWidgets);
    await tester.tap(downPath.first);
    await pause(tester, 900);
    expect(find.text('Transferred'), findsWidgets);
    expect(find.text('Request'), findsOneWidget);
    expect(find.text('Response'), findsOneWidget);

    expect(Jala.store.entries.length, greaterThan(beforeCount));
  });
}
