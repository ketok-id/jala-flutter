import 'package:flutter/material.dart';

import '../l10n/jala_localizations.dart';

/// Bottom sheet documenting the `JalaFilter` grammar, opened from the
/// filter bar's help icon.
class JalaFilterHelpSheet extends StatelessWidget {
  /// Creates the filter grammar help sheet.
  const JalaFilterHelpSheet({super.key});

  /// The DSL terms themselves are never translated — they are syntax, and
  /// forking them per locale would break every shared filter string. Only
  /// the prose describing each one moves.
  static List<(String, String)> _rows(JalaLocalizations l10n) =>
      <(String, String)>[
        ('method: / m:', l10n.filterHelpMethod),
        ('status: / s:', l10n.filterHelpStatus),
        ('host: / d:', l10n.filterHelpHost),
        ('path:', l10n.filterHelpPath),
        ('type: / t:', l10n.filterHelpType),
        ('larger-than:', l10n.filterHelpLargerThan),
        ('slower-than:', l10n.filterHelpSlowerThan),
        ('is:replay', l10n.filterHelpIsReplay),
        ('is:mocked', l10n.filterHelpIsMocked),
        ('op:', l10n.filterHelpOp),
        ('is:graphql', l10n.filterHelpIsGraphql),
        ('is:subscription', l10n.filterHelpIsSubscription),
        ('is:ws', l10n.filterHelpIsWs),
        ('body:', l10n.filterHelpBody),
        ('bare text', l10n.filterHelpBareText),
        ('-term', l10n.filterHelpNegate),
      ];

  @override
  Widget build(BuildContext context) {
    final JalaLocalizations l10n = JalaLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        // Scrollable because the content is a fixed list of rows whose
        // height depends on the locale: Indonesian overflowed this sheet by
        // 4px on a 1080x2400 phone (Track H device pass). English merely
        // happened to fit — a shorter screen or a third locale would have
        // hit the same wall.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.filterHelpTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l10n.filterHelpIntro,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final (String term, String desc) in _rows(l10n))
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
      ),
    );
  }
}
