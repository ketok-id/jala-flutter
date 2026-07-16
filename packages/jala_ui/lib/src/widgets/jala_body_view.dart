import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../util/format.dart';
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
        final List<JalaMultipartPart>? multipart = CapturedBodyMultipart
            .partsOf(body);
        if (multipart != null) {
          return _MultipartPartsTable(parts: multipart);
        }
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
          message: _binaryMessage(body),
        );
      case BodyKind.stream:
        return const _InfoCard(
          icon: Icons.stream,
          message: 'Stream — metadata only, body not captured',
        );
      case BodyKind.image:
        return _ImageBodyView(body: body);
    }
  }

  Widget _selectableText(String text) => SelectableText(
    text,
    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
  );

  /// Shared with [_ImageBodyView]'s `Image.memory` `errorBuilder`, so a
  /// corrupted image capture reads identically to plain metadata-only
  /// binary.
  static String _binaryMessage(CapturedBody body) =>
      'Binary — ${body.originalSize ?? 'unknown'} bytes captured '
      '(metadata only)';
}

/// Renders a [BodyKind.image] capture: a constrained inline preview with a
/// size/mime caption, tapping into a full-screen pinch-zoom viewer.
class _ImageBodyView extends StatelessWidget {
  const _ImageBodyView({required this.body});

  final CapturedBody body;

  @override
  Widget build(BuildContext context) {
    final Uint8List? bytes = body.bytes;
    if (bytes == null) {
      // Defensive only: BodyKind.image should always carry bytes.
      return _InfoCard(
        icon: Icons.data_object,
        message: JalaBodyView._binaryMessage(body),
      );
    }

    final String mime = body.contentType ?? 'image';
    final String caption = '$mime · ${humanizeBytes(body.originalSize)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext _) => _JalaFullScreenImage(bytes: bytes),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder:
                  (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) => _InfoCard(
                    icon: Icons.broken_image,
                    message: JalaBodyView._binaryMessage(body),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(caption, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Full-screen, pinch-to-zoom viewer pushed when an inline image preview is
/// tapped. Pushed via the nearest [Navigator] (the inspector's own, when
/// shown inside `JalaInspector`/`JalaCallDetailScreen`).
class _JalaFullScreenImage extends StatelessWidget {
  const _JalaFullScreenImage({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 6,
          child: Image.memory(bytes),
        ),
      ),
    );
  }
}

/// Renders a `{"@multipart": [...]}` capture (see B3 in
/// docs/plans/track-b-v0.2.md) as a name/filename/content-type/size table
/// instead of the raw JSON tree.
class _MultipartPartsTable extends StatelessWidget {
  const _MultipartPartsTable({required this.parts});

  final List<JalaMultipartPart> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Multipart body with no parts'),
      );
    }
    final TextStyle? headerStyle = Theme.of(context).textTheme.labelLarge;
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: FlexColumnWidth(),
        1: FlexColumnWidth(),
        2: FlexColumnWidth(),
        3: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: <TableRow>[
        TableRow(
          children: <Widget>[
            _cell(Text('Name', style: headerStyle)),
            _cell(Text('Filename', style: headerStyle)),
            _cell(Text('Content-Type', style: headerStyle)),
            _cell(Text('Size', style: headerStyle)),
          ],
        ),
        for (final JalaMultipartPart part in parts)
          TableRow(
            children: <Widget>[
              _cell(SelectableText(part.name)),
              _cell(SelectableText(part.filename ?? '—')),
              _cell(SelectableText(part.contentType ?? '—')),
              _cell(Text(humanizeBytes(part.size))),
            ],
          ),
      ],
    );
  }

  Widget _cell(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: child,
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
