import 'package:flutter/material.dart';
import 'package:jala/jala.dart';

/// Minimal Jala example: no HTTP client wired up, just the overlay.
///
/// See `examples/jala_example` in the repository root for a full manual QA
/// rig that fires real requests via `jala_dio`.
void main() {
  Jala.initialize(); // enabled: kDebugMode
  runApp(const JalaExampleMinApp());
}

/// Root widget of the minimal example.
class JalaExampleMinApp extends StatelessWidget {
  /// Creates the minimal example app.
  const JalaExampleMinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: JalaOverlay(
        child: Scaffold(
          appBar: AppBar(title: const Text('Jala example')),
          body: const Center(
            child: ElevatedButton(
              onPressed: Jala.open, // or tap the floating bubble
              child: Text('Open Jala inspector'),
            ),
          ),
        ),
      ),
    );
  }
}
