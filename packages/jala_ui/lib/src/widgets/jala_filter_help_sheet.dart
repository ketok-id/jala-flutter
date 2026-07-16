import 'package:flutter/material.dart';

/// Bottom sheet documenting the `JalaFilter` grammar, opened from the
/// filter bar's help icon.
class JalaFilterHelpSheet extends StatelessWidget {
  /// Creates the filter grammar help sheet.
  const JalaFilterHelpSheet({super.key});

  static const List<(String, String)> _rows = <(String, String)>[
    ('method: / m:', 'HTTP method; comma list allowed (m:get,post)'),
    (
      'status: / s:',
      'exact code (status:404), class (status:4xx), s:error, s:pending',
    ),
    ('host: / d:', 'host match; * wildcard allowed (host:*.example.com)'),
    ('path:', 'substring of the URL path'),
    ('type: / t:', 'substring of the response content-type'),
    ('larger-than:', 'responseSize > n bytes (k/m suffixes, e.g. 10k, 2m)'),
    ('slower-than:', 'duration > n milliseconds'),
    ('is:replay', 'the call is a replay of another entry'),
    ('body:', 'substring in captured request or response body'),
    ('bare text', 'substring of method + full URL'),
    ('-term', 'prefix any term with - to negate it'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Filter grammar',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Space-separated terms are ANDed together. All matching is '
              'case-insensitive.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final (String term, String desc) in _rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: RichText(
                  text: TextSpan(
                    children: <TextSpan>[
                      TextSpan(
                        text: term,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: '  $desc',
                        style: DefaultTextStyle.of(context).style,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
