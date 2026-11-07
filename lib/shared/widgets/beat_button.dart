import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

enum BeatButtonTone { primary, stop, tonal }

class BeatButton extends StatefulWidget {
  const BeatButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.busy = false,
    this.tone = BeatButtonTone.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final BeatButtonTone tone;

  @override
  State<BeatButton> createState() => _BeatButtonState();
}

class _BeatButtonState extends State<BeatButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortestSide < 300;
    final enabled = widget.onPressed != null && !widget.busy;
    final (background, foreground, border) = switch (widget.tone) {
      BeatButtonTone.primary => (
          scheme.primary,
          scheme.onPrimary,
          Colors.transparent,
        ),
      BeatButtonTone.stop => (
          scheme.surfaceContainerHighest,
          scheme.error,
          scheme.error.withValues(alpha: 0.34),
        ),
      BeatButtonTone.tonal => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          Colors.transparent,
        ),
    };

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: shortestSide * 0.60),
        child: Listener(
          onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.965 : 1,
            duration: AppMotion.fast,
            curve: AppMotion.springy,
            child: SizedBox(
              width: double.infinity,
              height: compact ? 44 : 60,
              child: FilledButton.icon(
                onPressed: enabled ? widget.onPressed : null,
                style: FilledButton.styleFrom(
                  backgroundColor: background,
                  foregroundColor: foreground,
                  disabledBackgroundColor: background.withValues(alpha: 0.55),
                  disabledForegroundColor: foreground.withValues(alpha: 0.6),
                  padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 18),
                  shape: StadiumBorder(
                    side: BorderSide(color: border, width: 1.2),
                  ),
                  textStyle: text.labelLarge?.copyWith(
                    fontSize: compact ? 10.5 : 13,
                    letterSpacing: compact ? 0.2 : 0.7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                icon: widget.busy
                    ? SizedBox(
                        width: compact ? 14 : 18,
                        height: compact ? 14 : 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.1,
                          color: foreground,
                        ),
                      )
                    : Icon(widget.icon, size: compact ? 17 : 21),
                label: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
