import 'package:flutter/material.dart';

/// A small pill showing an HTTP method.
class JalaMethodChip extends StatelessWidget {
  /// Creates a method chip for [method].
  const JalaMethodChip({required this.method, super.key});

  /// The HTTP method to display (e.g. `GET`).
  final String method;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
