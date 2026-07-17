import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jala_core/jala_core.dart';

import '../util/format.dart';
import '../widgets/jala_themed_page.dart';

/// Sentinel used for the "Custom" radio option — not a real
/// `JalaThrottleProfile.id` (those are `slow3g`/`fast3g`/`flaky`/`offline`),
/// just a marker for local selection state.
const String _customId = 'custom';

/// Screen to activate/deactivate network throttling: "Off", the built-in
/// presets, a custom profile editor, and a host-pattern scope field.
///
/// Reachable from the inspector AppBar's speed icon (see
/// docs/plans/track-e-v0.5.md E3). Reads/writes
/// `JalaBinding.instance.throttleRegistry` directly — there is no local
/// "draft" state that isn't already live once a preset or the custom
/// profile is selected/applied.
class JalaThrottleScreen extends StatefulWidget {
  /// Creates the throttle screen.
  const JalaThrottleScreen({super.key});

  /// Route factory.
  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => const JalaThrottleScreen(),
    );
  }

  @override
  State<JalaThrottleScreen> createState() => _JalaThrottleScreenState();
}

class _JalaThrottleScreenState extends State<JalaThrottleScreen> {
  late final TextEditingController _hostPatternController;
  late final TextEditingController _latencyController;
  late final TextEditingController _jitterController;
  late final TextEditingController _downloadController;
  late final TextEditingController _uploadController;

  /// `null` = Off, a preset's [JalaThrottleProfile.id], or [_customId].
  String? _selection;
  double _dropPercent = 0;

  JalaThrottleRegistry get _registry => JalaBinding.instance.throttleRegistry;

  @override
  void initState() {
    super.initState();
    final JalaThrottleProfile? active = _registry.activeProfile;
    final bool activeIsPreset =
        active != null &&
        JalaThrottleProfile.presets.any((JalaThrottleProfile p) => p.id == active.id);
    _selection = active == null
        ? null
        : (activeIsPreset ? active.id : _customId);
    _hostPatternController = TextEditingController(
      text: _registry.hostPattern ?? '',
    );
    final bool seedFromCustom = active != null && !activeIsPreset;
    _latencyController = TextEditingController(
      text: seedFromCustom ? '${active.latencyMs}' : '',
    );
    _jitterController = TextEditingController(
      text: seedFromCustom && active.jitterMs != null
          ? '${active.jitterMs}'
          : '',
    );
    _downloadController = TextEditingController(
      text: seedFromCustom && active.downloadBytesPerSec != null
          ? '${active.downloadBytesPerSec! ~/ 1024}'
          : '',
    );
    _uploadController = TextEditingController(
      text: seedFromCustom && active.uploadBytesPerSec != null
          ? '${active.uploadBytesPerSec! ~/ 1024}'
          : '',
    );
    _dropPercent = seedFromCustom ? active.dropRate * 100 : 0;
  }

  @override
  void dispose() {
    _hostPatternController.dispose();
    _latencyController.dispose();
    _jitterController.dispose();
    _downloadController.dispose();
    _uploadController.dispose();
    super.dispose();
  }

  String? get _hostPattern {
    final String text = _hostPatternController.text.trim();
    return text.isEmpty ? null : text;
  }

  void _onRadioChanged(String? value) {
    if (value == null) {
      setState(() => _selection = null);
      _registry.clear();
      return;
    }
    if (value == _customId) {
      setState(() => _selection = _customId);
      return; // Applied explicitly via the "Apply" button below.
    }
    final JalaThrottleProfile preset = JalaThrottleProfile.presets.firstWhere(
      (JalaThrottleProfile p) => p.id == value,
    );
    setState(() => _selection = value);
    _registry.setActive(preset, hostPattern: _hostPattern);
  }

  void _applyCustom() {
    final int latencyMs = int.tryParse(_latencyController.text.trim()) ?? 0;
    final int? jitterMs = int.tryParse(_jitterController.text.trim());
    final int? downloadKBps = int.tryParse(_downloadController.text.trim());
    final int? uploadKBps = int.tryParse(_uploadController.text.trim());
    final JalaThrottleProfile custom = JalaThrottleProfile(
      id: _customId,
      name: 'Custom',
      latencyMs: latencyMs < 0 ? 0 : latencyMs,
      jitterMs: (jitterMs == null || jitterMs <= 0) ? null : jitterMs,
      downloadBytesPerSec: (downloadKBps == null || downloadKBps <= 0)
          ? null
          : downloadKBps * 1024,
      uploadBytesPerSec: (uploadKBps == null || uploadKBps <= 0)
          ? null
          : uploadKBps * 1024,
      dropRate: (_dropPercent / 100).clamp(0.0, 1.0),
    );
    setState(() => _selection = _customId);
    _registry.setActive(custom, hostPattern: _hostPattern);
  }

  /// Re-scopes the currently active profile (if any) to the new host
  /// pattern. When throttling is off (or a custom profile hasn't been
  /// applied yet), the text is just remembered for the next activation.
  void _onHostPatternChanged(String _) {
    final JalaThrottleProfile? active = _registry.activeProfile;
    if (active != null) {
      _registry.setActive(active, hostPattern: _hostPattern);
    }
  }

  static String _summarize(JalaThrottleProfile p) {
    final List<String> parts = <String>[
      '${p.latencyMs}ms'
          '${p.jitterMs != null ? ' ±${p.jitterMs}ms' : ''} latency',
    ];
    if (p.downloadBytesPerSec != null) {
      parts.add('${humanizeBytes(p.downloadBytesPerSec)}/s down');
    }
    if (p.uploadBytesPerSec != null) {
      parts.add('${humanizeBytes(p.uploadBytesPerSec)}/s up');
    }
    if (p.dropRate > 0) {
      parts.add('${(p.dropRate * 100).round()}% drop');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return JalaThemedPage(
      child: Scaffold(
        appBar: AppBar(title: const Text('Throttle')),
        body: RadioGroup<String?>(
          groupValue: _selection,
          onChanged: _onRadioChanged,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const RadioListTile<String?>(
                value: null,
                title: Text('Off'),
                subtitle: Text('No simulated network conditions'),
              ),
              for (final JalaThrottleProfile preset
                  in JalaThrottleProfile.presets)
                RadioListTile<String?>(
                  value: preset.id,
                  title: Text(preset.name),
                  subtitle: Text(_summarize(preset)),
                ),
              const RadioListTile<String?>(
                value: _customId,
                title: Text('Custom'),
                subtitle: Text('Configure your own profile below'),
              ),
              if (_selection == _customId) ...<Widget>[
                const SizedBox(height: 8),
                _CustomEditor(
                  latencyController: _latencyController,
                  jitterController: _jitterController,
                  downloadController: _downloadController,
                  uploadController: _uploadController,
                  dropPercent: _dropPercent,
                  onDropPercentChanged: (double v) =>
                      setState(() => _dropPercent = v),
                  onApply: _applyCustom,
                ),
              ],
              const Divider(height: 32),
              TextField(
                controller: _hostPatternController,
                onChanged: _onHostPatternChanged,
                decoration: const InputDecoration(
                  labelText: 'Host pattern (glob, optional)',
                  hintText: '*.example.com — empty applies to all hosts',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomEditor extends StatelessWidget {
  const _CustomEditor({
    required this.latencyController,
    required this.jitterController,
    required this.downloadController,
    required this.uploadController,
    required this.dropPercent,
    required this.onDropPercentChanged,
    required this.onApply,
  });

  final TextEditingController latencyController;
  final TextEditingController jitterController;
  final TextEditingController downloadController;
  final TextEditingController uploadController;
  final double dropPercent;
  final ValueChanged<double> onDropPercentChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              controller: latencyController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Latency (ms)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: jitterController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Jitter ± (ms, optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: downloadController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Download KB/s (optional, unlimited if blank)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uploadController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Upload KB/s (optional, unlimited if blank)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drop rate: ${dropPercent.round()}%',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              value: dropPercent,
              max: 100,
              divisions: 20,
              label: '${dropPercent.round()}%',
              onChanged: onDropPercentChanged,
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onApply,
              child: const Text('Apply custom profile'),
            ),
          ],
        ),
      ),
    );
  }
}
