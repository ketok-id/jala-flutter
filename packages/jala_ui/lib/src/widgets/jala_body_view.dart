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
          return _JsonBodyView(decoded: decoded, rawText: text);
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

  /// The JSON view mode last chosen by the user, remembered for the app
  /// session so opening another body doesn't reset it back to [
  /// _JsonViewMode.tree]. Process-scoped (not persisted across restarts).
  static _JsonViewMode _lastJsonViewMode = _JsonViewMode.tree;

  /// Resets [_lastJsonViewMode] so widget tests don't leak the remembered
  /// mode from one test into the next.
  @visibleForTesting
  static void debugResetJsonViewMode() =>
      _lastJsonViewMode = _JsonViewMode.tree;
}

/// The ways a JSON body can be shown by [_JsonBodyView].
enum _JsonViewMode {
  /// The collapsible [JalaJsonTree].
  tree,

  /// Re-serialized with two-space indentation — readable formatted text.
  pretty,

  /// The verbatim captured text, exactly as it came off the wire.
  raw,
}

/// Wraps a decoded JSON body with a Tree · Pretty · Raw view switch.
///
/// [JalaBodyView] stays stateless; this small stateful widget owns the
/// selected [_JsonViewMode]. Pretty mode re-indents the decoded value for
/// readability; Raw mode shows [rawText] verbatim (not re-serialized) so it
/// reflects exactly what was captured, including key order and whitespace.
class _JsonBodyView extends StatefulWidget {
  const _JsonBodyView({required this.decoded, required this.rawText});

  /// The `jsonDecode`d value, rendered by [JalaJsonTree] in tree mode.
  final dynamic decoded;

  /// The original captured JSON text, shown verbatim in raw mode.
  final String rawText;

  @override
  State<_JsonBodyView> createState() => _JsonBodyViewState();
}

class _JsonBodyViewState extends State<_JsonBodyView> {
  static const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

  late _JsonViewMode _mode = JalaBodyView._lastJsonViewMode;

  /// Two-space-indented rendering of the decoded value. `decoded` came from
  /// `jsonDecode`, so it always re-encodes; the fallback is purely defensive.
  String get _prettyText {
    try {
      return _prettyEncoder.convert(widget.decoded);
    } on JsonUnsupportedObjectError {
      return widget.rawText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (_mode) {
      case _JsonViewMode.tree:
        content = JalaJsonTree(data: widget.decoded);
      case _JsonViewMode.pretty:
        content = _monoText(_prettyText);
      case _JsonViewMode.raw:
        content = _monoText(widget.rawText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: SegmentedButton<_JsonViewMode>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              showSelectedIcon: false,
              segments: const <ButtonSegment<_JsonViewMode>>[
                ButtonSegment<_JsonViewMode>(
                  value: _JsonViewMode.tree,
                  label: Text('Tree'),
                  icon: Icon(Icons.account_tree_outlined, size: 16),
                ),
                ButtonSegment<_JsonViewMode>(
                  value: _JsonViewMode.pretty,
                  label: Text('Pretty'),
                  icon: Icon(Icons.data_object, size: 16),
                ),
                ButtonSegment<_JsonViewMode>(
                  value: _JsonViewMode.raw,
                  label: Text('Raw'),
                  icon: Icon(Icons.notes, size: 16),
                ),
              ],
              selected: <_JsonViewMode>{_mode},
              onSelectionChanged: (Set<_JsonViewMode> selection) => setState(() {
                _mode = selection.first;
                JalaBodyView._lastJsonViewMode = _mode;
              }),
            ),
          ),
        ),
        content,
      ],
    );
  }

  Widget _monoText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: SelectableText(
      text,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    ),
  );
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
