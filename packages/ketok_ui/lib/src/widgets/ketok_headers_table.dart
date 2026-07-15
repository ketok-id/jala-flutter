import 'package:flutter/material.dart';

/// Renders a header map as a two-column, selectable table.
class KetokHeadersTable extends StatelessWidget {
  /// Creates a headers table for [headers].
  const KetokHeadersTable({required this.headers, super.key});

  /// Header name/value pairs, already redacted by the time they reach the
  /// UI (redaction happens at capture time in `ketok_core`).
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    if (headers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('No headers'),
      );
    }
    return Table(
      columnWidths: const <int, TableColumnWidth>{
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: <TableRow>[
        for (final MapEntry<String, String> header in headers.entries)
          TableRow(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: SelectableText(
                  header.key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: SelectableText(
                  header.value,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
