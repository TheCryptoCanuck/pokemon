import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dogquest/constants.dart';

/// Mode for the capture button.
enum CaptureMode { photo }

/// Animated capture button with pulsing ring, shutter flash effect,
/// and processing spinner state.
class CaptureButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isProcessing;
  final CaptureMode mode;

  const CaptureButton({
    super.key,
    required this.onTap,
    this.isProcessing = false,
    this.mode = CaptureMode.photo,
  });

  @override
  State<CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<CaptureButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  static const _buttonSize = 72.0;
  static const _outerRingSize = 88.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (!widget.isProcessing) widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: SizedBox(
        width: _outerRingSize + 16,
        height: _outerRingSize + 16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Pulsing outer ring ──
            if (!widget.isProcessing)
              Container(
                width: _outerRingSize,
                height: _outerRingSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 1200.ms,
                    curve: Curves.easeInOut,
                  )
                  .fade(begin: 0.6, end: 1.0, duration: 1200.ms),

            // ── Processing spinner ring ──
            if (widget.isProcessing)
              SizedBox(
                width: _outerRingSize,
                height: _outerRingSize,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.amber.withValues(alpha: 0.8),
                  ),
                ),
              ),

            // ── Shutter flash overlay ──
            if (_pressed)
              Container(
                width: _buttonSize + 40,
                height: _buttonSize + 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              )
                  .animate()
                  .fadeIn(duration: 50.ms)
                  .then()
                  .fadeOut(duration: 200.ms),

            // ── Main button ──
            AnimatedScale(
              scale: _pressed ? 0.85 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
              child: Container(
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isProcessing
                        ? [
                            bgCard,
                            bgCard.withValues(alpha: 0.8),
                          ]
                        : [
                            Colors.amber,
                            Colors.amber.shade700,
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isProcessing
                          ? Colors.transparent
                          : Colors.amber.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: widget.isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.amber),
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        color: bgDeep,
                        size: 32,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
