import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jala_core/jala_core.dart';

import '../theme/jala_theme.dart';
import 'jala_themed_page.dart';

/// A draggable floating bubble showing a 'J' glyph and a badge with the
/// current pending/error call count. Snaps to the nearest horizontal edge
/// on drag end.
///
/// Self-contained: position state is held internally, and the position the
/// user last dragged to is retained process-wide (see
/// [resetPositionForTesting]) rather than only in this widget's [State].
/// Embedders unmount the bubble while the inspector is open — `JalaOverlay`
/// does exactly that so it cannot cover list rows — and a position kept
/// only in [State] is lost on every such remount, snapping the bubble back
/// to the default edge each time the inspector closes.
///
/// Intended to be placed as the content of a root [Overlay] entry (which
/// lays out its children like a [Stack]), so this widget returns a
/// [Positioned] as its top-level widget.
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

  /// Where the user last dragged the bubble, or null if never dragged.
  ///
  /// Retained across mount/unmount so the bubble stays put when the
  /// inspector is opened and closed. Re-clamped to the current bounds on
  /// read, so a position stored before a rotation or resize can't strand
  /// the bubble off-screen.
  static Offset? _retainedPosition;

  /// Forgets the retained drag position, so a fresh bubble starts from
  /// [initialPosition] again. Intended for tests — process-wide state
  /// otherwise leaks between cases (mirrors `JalaBinding.resetForTesting`).
  static void resetPositionForTesting() => _retainedPosition = null;

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
      // Retained as it animates, so the edge the bubble settles on is what
      // a later remount restores.
      setState(() => _remember(animation.value));
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  Offset _currentPosition(Size bounds) => _clamp(
    _position ??
        JalaOverlayButton._retainedPosition ??
        widget.initialPosition ??
        Offset(bounds.width - widget.diameter - 16, bounds.height / 2),
    bounds,
  );

  /// Keeps a position inside [bounds]. Applied on read, not just on drag,
  /// because a retained position may have been stored under a different
  /// screen size (rotation, window resize, foldable).
  Offset _clamp(Offset position, Size bounds) {
    final double maxX = bounds.width - widget.diameter;
    final double maxY = bounds.height - widget.diameter;
    return Offset(
      position.dx.clamp(0.0, maxX < 0 ? 0.0 : maxX),
      position.dy.clamp(0.0, maxY < 0 ? 0.0 : maxY),
    );
  }

  void _remember(Offset position) {
    _position = position;
    JalaOverlayButton._retainedPosition = position;
  }

  void _onDragUpdate(DragUpdateDetails details, Size bounds) {
    setState(() {
      _remember(_clamp(_currentPosition(bounds) + details.delta, bounds));
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
