import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import 'jala_themed_page.dart';

/// A draggable floating bubble showing a 'J' glyph and a badge with the
/// current pending/error call count. Snaps to the nearest horizontal edge
/// on drag end.
///
/// Self-contained: position state is held internally. Intended to be
/// placed as the content of a root [Overlay] entry (which lays out its
/// children like a [Stack]), so this widget returns a [Positioned] as its
/// top-level widget.
class JalaOverlayButton extends StatefulWidget {
  /// Creates an overlay bubble.
  ///
  /// [onTap] is invoked when the bubble is tapped (not dragged) — the
  /// embedder decides what that does (typically opening the inspector).
  /// [initialPosition] seeds the bubble's starting position; if omitted it
  /// starts pinned to the right edge, vertically centered.
  const JalaOverlayButton({
    required this.onTap,
    super.key,
    this.initialPosition,
    this.diameter = 56,
  });

  /// Called when the bubble is tapped.
  final VoidCallback onTap;

  /// Starting position (top-left) of the bubble, in the coordinate space
  /// of the surrounding [Overlay]/[Stack].
  final Offset? initialPosition;

  /// Diameter of the circular bubble.
  final double diameter;

  @override
  State<JalaOverlayButton> createState() => _JalaOverlayButtonState();
}

class _JalaOverlayButtonState extends State<JalaOverlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _snapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  Offset? _position;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapController.addListener(() {
      final Animation<Offset>? animation = _snapAnimation;
      if (animation == null) return;
      setState(() => _position = animation.value);
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  Offset _currentPosition(Size bounds) =>
      _position ??
      widget.initialPosition ??
      Offset(bounds.width - widget.diameter - 16, bounds.height / 2);

  void _onDragUpdate(DragUpdateDetails details, Size bounds) {
    setState(() {
      final Offset next = _currentPosition(bounds) + details.delta;
      _position = Offset(
        next.dx.clamp(0, bounds.width - widget.diameter),
        next.dy.clamp(0, bounds.height - widget.diameter),
      );
    });
  }

  void _onDragEnd(Size bounds) {
    final Offset current = _currentPosition(bounds);
    final bool snapToLeft =
        (current.dx + widget.diameter / 2) < bounds.width / 2;
    final double targetX = snapToLeft ? 0.0 : bounds.width - widget.diameter;
    final Offset target = Offset(targetX, current.dy);
    _snapAnimation = Tween<Offset>(
      begin: current,
      end: target,
    ).animate(CurvedAnimation(parent: _snapController, curve: Curves.easeOut));
    unawaited(_snapController.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    // Top-level must be Positioned for Overlay/Stack parents. Use the
    // ambient MediaQuery size for bounds (same coordinate space as Overlay).
    final Size bounds = MediaQuery.sizeOf(context);
    final Offset position = _currentPosition(bounds);
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (DragUpdateDetails details) =>
            _onDragUpdate(details, bounds),
        onPanEnd: (DragEndDetails _) => _onDragEnd(bounds),
        child: JalaThemedPage(child: _JalaBubble(diameter: widget.diameter)),
      ),
    );
  }
}

class _JalaBubble extends StatelessWidget {
  const _JalaBubble({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final Stream<List<NetworkCallEntry>> watch =
        JalaBinding.instance.isInitialized
        ? JalaBinding.instance.store.watch
        : const Stream<List<NetworkCallEntry>>.empty();
    return StreamBuilder<List<NetworkCallEntry>>(
      stream: watch,
      initialData: const <NetworkCallEntry>[],
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<NetworkCallEntry>> snapshot,
          ) {
            final List<NetworkCallEntry> entries =
                snapshot.data ?? const <NetworkCallEntry>[];
            final int pending = entries
                .where(
                  (NetworkCallEntry e) => e.status == JalaCallStatus.pending,
                )
                .length;
            final int errors = entries
                .where(
                  (NetworkCallEntry e) =>
                      e.status == JalaCallStatus.error ||
                      (e.statusCode != null && e.statusCode! >= 500),
                )
                .length;
            final ColorScheme scheme = Theme.of(context).colorScheme;
            return SizedBox(
              width: diameter + 12,
              height: diameter + 12,
              child: Stack(
                clipBehavior: Clip.none,
                textDirection: TextDirection.ltr,
                children: <Widget>[
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: SizedBox(
                        width: diameter,
                        height: diameter,
                        child: Center(
                          child: Text(
                            'J',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: diameter * 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (errors > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _CountBadge(
                        count: errors,
                        color: JalaTheme.serverErrorColor,
                      ),
                    )
                  else if (pending > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _PendingBadge(count: pending),
                    ),
                ],
              ),
            );
          },
    );
  }
}

class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        alignment: Alignment.center,
        textDirection: TextDirection.ltr,
        children: <Widget>[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text(
            '$count',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
