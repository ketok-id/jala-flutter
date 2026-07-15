import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ketok_core/ketok_core.dart';

import '../theme/ketok_theme_controller.dart';
import '../widgets/ketok_call_list_tile.dart';
import '../widgets/ketok_filter_help_sheet.dart';
import '../widgets/ketok_themed_page.dart';
import 'ketok_call_detail_screen.dart';

/// Root screen of the Ketok inspector: filter bar, call list, and app bar
/// actions (clear, copy session HAR, theme toggle).
class KetokInspectorScreen extends StatefulWidget {
  /// Creates the inspector screen.
  const KetokInspectorScreen({this.onClose, super.key});

  /// Called when the user taps the close button. When null, no close
  /// button is shown (e.g. when the screen is pushed on a host navigator
  /// that provides its own back affordance).
  final VoidCallback? onClose;

  @override
  State<KetokInspectorScreen> createState() => _KetokInspectorScreenState();
}

class _KetokInspectorScreenState extends State<KetokInspectorScreen> {
  final TextEditingController _filterController = TextEditingController();
  KetokFilter _filter = KetokFilter.parse('');
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      setState(() => _filter = KetokFilter.parse(value));
    });
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Clear all captured calls?'),
        content: const Text(
          'This removes every entry from the inspector. This cannot be '
          'undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      KetokBinding.instance.store.clear();
    }
  }

  Future<void> _copySessionHar(
    BuildContext context,
    List<NetworkCallEntry> entries,
  ) async {
    final String har = HarExporter.exportSession(entries);
    await Clipboard.setData(ClipboardData(text: har));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied HAR for ${entries.length} '
          '${entries.length == 1 ? 'call' : 'calls'}',
        ),
      ),
    );
  }

  void _openHelp(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (BuildContext ctx) => const KetokFilterHelpSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KetokThemedPage(
      child: StreamBuilder<List<NetworkCallEntry>>(
        stream: KetokBinding.instance.store.watch,
        initialData: KetokBinding.instance.store.entries,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<NetworkCallEntry>> snapshot,
        ) {
          final List<NetworkCallEntry> all =
              snapshot.data ?? const <NetworkCallEntry>[];
          final List<NetworkCallEntry> filtered = _filter.isEmpty
              ? all
              : all.where(_filter.matches).toList();
          return Scaffold(
            appBar: AppBar(
              leading: widget.onClose == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close inspector',
                      onPressed: widget.onClose,
                    ),
              title: const Text('Ketok'),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear',
                  onPressed: all.isEmpty ? null : () => _confirmClear(context),
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share),
                  tooltip: 'Copy session as HAR',
                  onPressed: all.isEmpty
                      ? null
                      : () => _copySessionHar(context, all),
                ),
                const _ThemeToggleButton(),
              ],
            ),
            body: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _filterController,
                    onChanged: _onFilterChanged,
                    decoration: InputDecoration(
                      hintText: 'method:get status:4xx host:api.* …',
                      prefixIcon: const Icon(Icons.filter_alt_outlined),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.help_outline),
                        tooltip: 'Filter grammar',
                        onPressed: () => _openHelp(context),
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                Expanded(
                  child: all.isEmpty
                      ? const _EmptyState(
                          message: 'No network calls captured yet.',
                        )
                      : filtered.isEmpty
                      ? _EmptyState(
                          message:
                              'No calls match "${_filterController.text}".',
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const Divider(height: 1),
                          itemBuilder: (BuildContext context, int index) {
                            final NetworkCallEntry entry = filtered[index];
                            return KetokCallListTile(
                              entry: entry,
                              onTap: () => Navigator.of(context).push(
                                KetokCallDetailScreen.route(entry.id),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final KetokThemeController controller = KetokThemeScope.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        final IconData icon = switch (controller.mode) {
          KetokThemeMode.system => Icons.brightness_auto,
          KetokThemeMode.light => Icons.light_mode,
          KetokThemeMode.dark => Icons.dark_mode,
        };
        return IconButton(
          icon: Icon(icon),
          tooltip: 'Theme: ${controller.mode.name}',
          onPressed: controller.cycle,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
