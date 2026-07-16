import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_core/jala_core.dart';

import '../widgets/jala_themed_page.dart';

/// Create or edit a single [JalaMockRule].
class JalaMockEditorScreen extends StatefulWidget {
  /// Opens the editor for a new rule, or [existing] when non-null.
  const JalaMockEditorScreen({this.existing, super.key});

  /// Rule being edited, or null for a new rule.
  final JalaMockRule? existing;

  /// Route factory.
  static Route<void> route({JalaMockRule? existing}) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          JalaMockEditorScreen(existing: existing),
    );
  }

  /// Prefills the editor from a captured call ("Mock this").
  static Route<void> routeFromEntry(NetworkCallEntry entry) {
    final String body = entry.responseBody.text ?? '';
    final Map<String, String> headers = Map<String, String>.from(
      entry.responseHeaders,
    );
    final JalaMockRule seed = JalaMockRule(
      id: JalaIdGenerator.next(),
      name: '${entry.method} ${entry.uri.path}',
      method: entry.method,
      urlPattern: entry.uri.toString(),
      action: MockResponse(
        statusCode: entry.statusCode ?? 200,
        headers: headers,
        body: body,
      ),
    );
    return route(existing: seed);
  }

  @override
  State<JalaMockEditorScreen> createState() => _JalaMockEditorScreenState();
}

class _JalaMockEditorScreenState extends State<JalaMockEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _urlPattern;
  late final TextEditingController _bodyContains;
  late final TextEditingController _statusCode;
  late final TextEditingController _body;
  late final TextEditingController _delayMs;
  late final TextEditingController _headersText;

  String? _method; // null = ANY
  String _actionType = 'response'; // response | failure | delay
  MockFailureKind _failureKind = MockFailureKind.connectionError;
  late final String _id;
  late final bool _isNew;

  @override
  void initState() {
    super.initState();
    final JalaMockRule? e = widget.existing;
    _isNew = e == null ||
        !JalaBinding.instance.mockRegistry.rules.any(
          (JalaMockRule r) => r.id == e.id,
        );
    _id = e?.id ?? JalaIdGenerator.next();
    _name = TextEditingController(text: e?.name ?? '');
    _urlPattern = TextEditingController(text: e?.urlPattern ?? 'https://*');
    _bodyContains = TextEditingController(text: e?.bodyContains ?? '');
    _method = e?.method;
    final MockAction action = e?.action ?? const MockResponse(statusCode: 200);
    switch (action) {
      case final MockResponse r:
        _actionType = 'response';
        _statusCode = TextEditingController(text: '${r.statusCode}');
        _body = TextEditingController(text: r.body);
        _headersText = TextEditingController(text: _headersToText(r.headers));
        _delayMs = TextEditingController(
          text: r.delay != null ? '${r.delay!.inMilliseconds}' : '',
        );
      case final MockFailure f:
        _actionType = 'failure';
        _failureKind = f.kind;
        _statusCode = TextEditingController(text: '200');
        _body = TextEditingController();
        _headersText = TextEditingController();
        _delayMs = TextEditingController(
          text: f.delay != null ? '${f.delay!.inMilliseconds}' : '',
        );
      case final MockDelay d:
        _actionType = 'delay';
        _statusCode = TextEditingController(text: '200');
        _body = TextEditingController();
        _headersText = TextEditingController();
        _delayMs = TextEditingController(text: '${d.delay.inMilliseconds}');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _urlPattern.dispose();
    _bodyContains.dispose();
    _statusCode.dispose();
    _body.dispose();
    _delayMs.dispose();
    _headersText.dispose();
    super.dispose();
  }

  static String _headersToText(Map<String, String> headers) {
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  static Map<String, String> _parseHeaders(String text) {
    final Map<String, String> out = <String, String>{};
    for (final String line in text.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final int colon = trimmed.indexOf(':');
      if (colon <= 0) continue;
      out[trimmed.substring(0, colon).trim()] =
          trimmed.substring(colon + 1).trim();
    }
    return out;
  }

  int _matchCount(JalaMockRule draft) {
    if (!JalaBinding.instance.isInitialized) return 0;
    return JalaBinding.instance.store.entries.where((NetworkCallEntry e) {
      return draft.matches(
        method: e.method,
        uri: e.uri,
        bodyText: e.requestBody.text,
      );
    }).length;
  }

  JalaMockRule _buildRule() {
    final int? delayMs = int.tryParse(_delayMs.text.trim());
    final Duration? delay =
        delayMs != null && delayMs > 0 ? Duration(milliseconds: delayMs) : null;
    final MockAction action = switch (_actionType) {
      'failure' => MockFailure(kind: _failureKind, delay: delay),
      'delay' => MockDelay(
        delay: delay ?? const Duration(milliseconds: 500),
      ),
      _ => MockResponse(
        statusCode: int.tryParse(_statusCode.text.trim()) ?? 200,
        headers: _parseHeaders(_headersText.text),
        body: _body.text,
        delay: delay,
      ),
    };
    return JalaMockRule(
      id: _id,
      name: _name.text.trim().isEmpty ? 'Untitled rule' : _name.text.trim(),
      enabled: true,
      method: _method,
      urlPattern: _urlPattern.text.trim().isEmpty
          ? '*'
          : _urlPattern.text.trim(),
      bodyContains: _bodyContains.text.trim().isEmpty
          ? null
          : _bodyContains.text.trim(),
      action: action,
    );
  }

  void _save() {
    final JalaMockRule rule = _buildRule();
    if (_isNew) {
      JalaBinding.instance.mockRegistry.add(rule);
    } else {
      JalaBinding.instance.mockRegistry.update(rule);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final JalaMockRule draft = _buildRule();
    final int matches = _matchCount(draft);

    return JalaThemedPage(
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New mock' : 'Edit mock'),
          actions: <Widget>[
            TextButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              // ignore: deprecated_member_use
              value: _method,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('ANY'),
                ),
                for (final String m in <String>[
                  'GET',
                  'POST',
                  'PUT',
                  'PATCH',
                  'DELETE',
                  'HEAD',
                  'OPTIONS',
                ])
                  DropdownMenuItem<String?>(value: m, child: Text(m)),
              ],
              onChanged: (String? v) => setState(() => _method = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlPattern,
              decoration: const InputDecoration(
                labelText: 'URL pattern (glob, * wildcards)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              'Matches $matches captured call${matches == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyContains,
              decoration: const InputDecoration(
                labelText: 'Body contains (optional)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Action', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'response',
                  label: Text('Response'),
                ),
                ButtonSegment<String>(
                  value: 'failure',
                  label: Text('Failure'),
                ),
                ButtonSegment<String>(value: 'delay', label: Text('Delay')),
              ],
              selected: <String>{_actionType},
              onSelectionChanged: (Set<String> s) {
                setState(() => _actionType = s.first);
              },
            ),
            const SizedBox(height: 12),
            if (_actionType == 'response') ...<Widget>[
              TextField(
                controller: _statusCode,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  labelText: 'Status code',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _headersText,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Headers (Name: value per line)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: 'Body',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
            if (_actionType == 'failure') ...<Widget>[
              DropdownButtonFormField<MockFailureKind>(
                // ignore: deprecated_member_use
                value: _failureKind,
                decoration: const InputDecoration(
                  labelText: 'Failure kind',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<MockFailureKind>>[
                  for (final MockFailureKind k in MockFailureKind.values)
                    DropdownMenuItem<MockFailureKind>(
                      value: k,
                      child: Text(k.name),
                    ),
                ],
                onChanged: (MockFailureKind? v) {
                  if (v != null) setState(() => _failureKind = v);
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _delayMs,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: _actionType == 'delay'
                    ? 'Delay (ms, required)'
                    : 'Delay (ms, optional)',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
