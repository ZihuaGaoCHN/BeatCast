import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

class BeatRing extends StatelessWidget {
  const BeatRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 176,
    this.live = false,
  });

  final double progress;
  final Widget child;
  final double size;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress.clamp(0, 1)),
        duration: AppMotion.base,
        curve: AppMotion.decelerate,
        builder: (context, value, _) {
          return RepaintBoundary(
            child: CustomPaint(
              painter: _BeatRingPainter(
                progress: value,
                active: scheme.primary,
                highlight: scheme.secondary,
                track: scheme.outlineVariant.withValues(alpha: 0.55),
                live: live,
              ),
              child: Center(child: child),
            ),
          );
        },
      ),
    );
  }
}

class _BeatRingPainter extends CustomPainter {
  const _BeatRingPainter({
    required this.progress,
    required this.active,
    required this.highlight,
    required this.track,
    required this.live,
  });

  final double progress;
  final Color active;
  final Color highlight;
  final Color track;
  final bool live;

  static const _start = math.pi * 0.72;
  static const _sweep = math.pi * 1.56;
  static const _tickCount = 48;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.2;
    final activeTicks = (progress * _tickCount).round();

    for (var i = 0; i < _tickCount; i++) {
      final t = i / (_tickCount - 1);
      final angle = _start + _sweep * t;
      final isActive = i < activeTicks;
      final inner = radius - (isActive ? 11 : 7);
      final outer = radius - 1;
      tickPaint.color = isActive
          ? Color.lerp(active, highlight, t)!.withValues(alpha: 0.95)
          : track;
      canvas.drawLine(
        center + Offset(math.cos(angle), math.sin(angle)) * inner,
        center + Offset(math.cos(angle), math.sin(angle)) * outer,
        tickPaint,
      );
    }

    // A soft inner well makes the numeric hero read as a physical dial.
    final well = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = track.withValues(alpha: 0.4);
    canvas.drawCircle(center, radius - 22, well);

    if (progress > 0.01) {
      final endAngle = _start + _sweep * progress;
      final dot = center + Offset(math.cos(endAngle), math.sin(endAngle)) * (radius - 6);
      canvas.drawCircle(
        dot,
        4.2,
        Paint()..color = highlight,
      );
      canvas.drawCircle(
        dot,
        8.5,
        Paint()..color = highlight.withValues(alpha: 0.12),
      );
    }

    if (live) {
      final accent = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = active.withValues(alpha: 0.24);
      canvas.drawCircle(center, radius - 32, accent);
    }
  }

  @override
  bool shouldRepaint(covariant _BeatRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.live != live ||
      oldDelegate.active != active ||
      oldDelegate.highlight != highlight ||
      oldDelegate.track != track;
}
