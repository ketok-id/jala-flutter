import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';

/// Manual QA rig for Jala v0.1.
///
/// Fires a variety of requests against httpbin.org (jsonplaceholder as
/// backup for simple GETs) so you can exercise filters, export, replay,
/// redaction, truncation, and error paths in the inspector.
void main() {
  // The hosted demo (GitHub Pages) is a release build, where the
  // `enabled: kDebugMode` default would turn Jala off — opt in explicitly.
  Jala.initialize(config: JalaConfig(enabled: true));
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: <String, dynamic>{
        // Demonstrates capture-time redaction in the inspector.
        'Authorization': 'Bearer demo-secret-token-do-not-leak',
      },
    ),
  );
  JalaDio.attach(dio);
  runApp(JalaOverlay(child: JalaExampleApp(dio: dio)));
}

/// Root of the example app.
class JalaExampleApp extends StatelessWidget {
  /// Creates the example app bound to [dio].
  const JalaExampleApp({required this.dio, super.key});

  /// Shared Dio instance with Jala attached.
  final Dio dio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jala Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: _DemoHome(dio: dio),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome({required this.dio});

  final Dio dio;

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  String _last = 'Tap a button to fire a request. Open Jala via the J bubble.';
  CancelToken? _cancelToken;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _last = 'Running: $label…');
    try {
      await action();
      if (!mounted) return;
      setState(() => _last = 'OK: $label');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _last = 'Done: $label → $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final Dio dio = widget.dio;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jala QA Rig'),
        actions: <Widget>[
          const IconButton(
            tooltip: 'Open Jala inspector',
            icon: Icon(Icons.bug_report_outlined),
            onPressed: Jala.open,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(_last, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          const Text(
            'Primary host: https://httpbin.org\n'
            'Backup: https://jsonplaceholder.typicode.com',
          ),
          const Divider(height: 32),
          _btn('GET json', () => _run('GET json', () async {
            await dio.get<dynamic>('https://httpbin.org/json');
          })),
          _btn('POST json', () => _run('POST json', () async {
            await dio.post<dynamic>(
              'https://httpbin.org/post',
              data: <String, dynamic>{'hello': 'jala', 'n': 42},
            );
          })),
          _btn('404', () => _run('404', () async {
            await dio.get<dynamic>('https://httpbin.org/status/404');
          })),
          _btn('500', () => _run('500', () async {
            await dio.get<dynamic>('https://httpbin.org/status/500');
          })),
          _btn('Slow (delay/3)', () => _run('slow', () async {
            await dio.get<dynamic>('https://httpbin.org/delay/3');
          })),
          _btn('Redirect', () => _run('redirect', () async {
            await dio.get<dynamic>('https://httpbin.org/redirect/2');
          })),
          _btn('Image (png)', () => _run('image', () async {
            await dio.get<List<int>>(
              'https://httpbin.org/image/png',
              options: Options(responseType: ResponseType.bytes),
            );
          })),
          _btn('Large (~1MB)', () => _run('large', () async {
            // 1 MiB of bytes — proves body truncation in the inspector.
            await dio.get<dynamic>('https://httpbin.org/bytes/1048576');
          })),
          _btn('Gzip', () => _run('gzip', () async {
            await dio.get<dynamic>('https://httpbin.org/gzip');
          })),
          _btn('Multipart upload', () => _run('multipart', () async {
            final FormData form = FormData.fromMap(<String, dynamic>{
              'field': 'jala',
              'file': MultipartFile.fromString(
                'hello from jala example',
                filename: 'hello.txt',
              ),
            });
            await dio.post<dynamic>('https://httpbin.org/post', data: form);
          })),
          _btn('Cancel in-flight', () => _run('cancel', () async {
            _cancelToken?.cancel('user');
            _cancelToken = CancelToken();
            final CancelToken token = _cancelToken!;
            // Fire slow request then cancel shortly after.
            unawaited(
              dio
                  .get<dynamic>(
                    'https://httpbin.org/delay/5',
                    cancelToken: token,
                  )
                  .catchError((Object _) => Response<dynamic>(
                        requestOptions: RequestOptions(),
                      )),
            );
            await Future<void>.delayed(const Duration(milliseconds: 300));
            token.cancel('cancelled by example');
          })),
          _btn('Bad host (error)', () => _run('bad host', () async {
            await dio.get<dynamic>('https://this-host-does-not-exist.jala.dev/');
          })),
          _btn('Backup GET (jsonplaceholder)', () => _run('backup GET', () async {
            await dio.get<dynamic>(
              'https://jsonplaceholder.typicode.com/todos/1',
            );
          })),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonal(
        onPressed: onPressed,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
      ),
    );
  }
}
