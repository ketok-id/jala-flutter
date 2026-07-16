import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../widgets/jala_themed_page.dart';

/// Edit-and-resend composer prefilled from a captured call.
class JalaRequestComposerScreen extends StatefulWidget {
  /// Creates a composer for [entry].
  const JalaRequestComposerScreen({required this.entry, super.key});

  /// Source call to edit.
  final NetworkCallEntry entry;

  /// Route factory.
  static Route<void> route(NetworkCallEntry entry) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          JalaRequestComposerScreen(entry: entry),
    );
  }

  @override
  State<JalaRequestComposerScreen> createState() =>
      _JalaRequestComposerScreenState();
}

class _JalaRequestComposerScreenState extends State<JalaRequestComposerScreen> {
  late final TextEditingController _method;
  late final TextEditingController _url;
  late final TextEditingController _headers;
  late final TextEditingController _body;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final NetworkCallEntry e = widget.entry;
    _method = TextEditingController(text: e.method);
    _url = TextEditingController(text: e.uri.toString());
    _headers = TextEditingController(
      text: e.requestHeaders.entries
          .where((MapEntry<String, String> h) => h.value != JalaRedactor.mask)
          .map((MapEntry<String, String> h) => '${h.key}: ${h.value}')
          .join('\n'),
    );
    _body = TextEditingController(text: e.requestBody.text ?? '');
  }

  @override
  void dispose() {
    _method.dispose();
    _url.dispose();
    _headers.dispose();
    _body.dispose();
    super.dispose();
  }

  Map<String, String> _parseHeaders(String text) {
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

  Future<void> _send() async {
    final Uri? uri = Uri.tryParse(_url.text.trim());
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid absolute URL')),
      );
      return;
    }
    setState(() => _sending = true);
    final bool ok = await JalaBinding.instance.replayRegistry.replayModified(
      widget.entry,
      method: _method.text.trim().isEmpty
          ? null
          : _method.text.trim().toUpperCase(),
      uri: uri,
      headers: _parseHeaders(_headers.text),
      body: _body.text,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Request sent' : 'No replayer attached'),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return JalaThemedPage(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit & resend'),
          actions: <Widget>[
            TextButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _method,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headers,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Headers (Name: value per line)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              minLines: 6,
              maxLines: 16,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
