import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import 'jala_json_tree.dart';

/// Renders a [CapturedBody] according to its [BodyKind].
class JalaBodyView extends StatelessWidget {
  /// Creates a body view for [body].
  const JalaBodyView({required this.body, super.key});

  /// The captured body to render.
  final CapturedBody body;

  @override
  Widget build(BuildContext context) {
    switch (body.kind) {
      case BodyKind.none:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('empty'),
        );
      case BodyKind.json:
        final String text = body.text ?? '';
        try {
          final dynamic decoded = jsonDecode(text);
          return JalaJsonTree(data: decoded);
        } on FormatException {
          return _selectableText(text);
        }
      case BodyKind.text:
        return _selectableText(body.text ?? '');
      case BodyKind.truncated:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _InfoCard(
              icon: Icons.content_cut,
              message:
                  'Truncated — ${body.text?.length ?? 0} chars shown of '
                  '${body.originalSize ?? '?'} bytes captured',
            ),
            const SizedBox(height: 8),
            _selectableText(body.text ?? ''),
          ],
        );
      case BodyKind.bytes:
        return _InfoCard(
          icon: Icons.data_object,
          message:
              'Binary — ${body.originalSize ?? 'unknown'} bytes captured '
              '(metadata only)',
        );
      case BodyKind.stream:
        return const _InfoCard(
          icon: Icons.stream,
          message: 'Stream — metadata only, body not captured',
        );
    }
  }

  Widget _selectableText(String text) => SelectableText(
    text,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
