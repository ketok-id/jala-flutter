import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../widgets/jala_themed_page.dart';
import 'jala_mock_editor_screen.dart';

/// List of mock rules with enable toggles and navigation to the editor.
class JalaMocksScreen extends StatelessWidget {
  /// Creates the mocks list screen.
  const JalaMocksScreen({super.key});

  /// Route that pushes this screen.
  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => const JalaMocksScreen(),
    );
  }

  String _actionSummary(MockAction action) {
    return switch (action) {
      MockResponse(:final int statusCode, :final Duration? delay) =>
        '→ $statusCode${delay != null ? ' · ${delay.inMilliseconds}ms' : ''}',
      MockFailure(:final MockFailureKind kind, :final Duration? delay) =>
        'fail ${kind.name}${delay != null ? ' · ${delay.inMilliseconds}ms' : ''}',
      MockDelay(:final Duration delay) => 'delay ${delay.inMilliseconds}ms',
    };
  }

  @override
  Widget build(BuildContext context) {
    return JalaThemedPage(
      child: StreamBuilder<List<JalaMockRule>>(
        stream: JalaBinding.instance.mockRegistry.watch,
        initialData: JalaBinding.instance.mockRegistry.rules,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JalaMockRule>> snapshot,
        ) {
          final List<JalaMockRule> rules =
              snapshot.data ?? const <JalaMockRule>[];
          return Scaffold(
            appBar: AppBar(title: const Text('Mocks')),
            floatingActionButton: FloatingActionButton(
              tooltip: 'Add mock rule',
              onPressed: () {
                Navigator.of(context).push(
                  JalaMockEditorScreen.route(),
                );
              },
              child: const Icon(Icons.add),
            ),
            body: rules.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No mock rules yet.\n'
                        'Add one, or use “Mock this” on a captured call.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rules.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final JalaMockRule rule = rules[index];
                      return Dismissible(
                        key: ValueKey<String>(rule.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Theme.of(context).colorScheme.error,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.onError,
                          ),
                        ),
                        onDismissed: (_) {
                          JalaBinding.instance.mockRegistry.remove(rule.id);
                        },
                        child: ListTile(
                          title: Text(rule.name.isEmpty ? rule.id : rule.name),
                          subtitle: Text(
                            '${rule.method ?? 'ANY'}  ${rule.urlPattern}\n'
                            '${_actionSummary(rule.action)}',
                          ),
                          isThreeLine: true,
                          trailing: Switch(
                            value: rule.enabled,
                            onChanged: (bool v) {
                              JalaBinding.instance.mockRegistry.setEnabled(
                                rule.id,
                                v,
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              JalaMockEditorScreen.route(existing: rule),
                            );
                          },
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
