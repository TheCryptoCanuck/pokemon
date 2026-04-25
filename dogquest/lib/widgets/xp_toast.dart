import 'package:flutter/material.dart';

/// A floating "+XP" toast that slides up and fades out.
///
/// Call [XpToast.show] after awarding XP to give the user visual feedback.
class XpToast {
  static void show(BuildContext context,
      {required int xp, String? multiplierLabel}) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _XpToastOverlay(
        xp: xp,
        multiplierLabel: multiplierLabel,
        onDone: () {
          entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _XpToastOverlay extends StatefulWidget {
  final int xp;
  final String? multiplierLabel;
  final VoidCallback onDone;

  const _XpToastOverlay({
    required this.xp,
    this.multiplierLabel,
    required this.onDone,
  });

  @override
  State<_XpToastOverlay> createState() => _XpToastOverlayState();
}

class _XpToastOverlayState extends State<_XpToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideY;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _slideY = Tween<double>(begin: 0, end: -50).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        // Stay fully visible for the first 40%, then fade out
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.15), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.multiplierLabel != null
        ? '+${widget.xp} XP (${widget.multiplierLabel})'
        : '+${widget.xp} XP';

    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.45,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slideY.value),
          child: Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          ),
        ),
        child: Center(
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
