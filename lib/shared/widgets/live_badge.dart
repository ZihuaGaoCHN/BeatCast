import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

enum LiveBadgeTone { idle, waiting, live, error }

class LiveBadge extends StatelessWidget {
  const LiveBadge({
    super.key,
    required this.label,
    this.tone = LiveBadgeTone.idle,
  });

  final String label;
  final LiveBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).shortestSide < 300;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final color = switch (tone) {
      LiveBadgeTone.live => scheme.secondary,
      LiveBadgeTone.waiting => scheme.tertiary,
      LiveBadgeTone.error => scheme.error,
      LiveBadgeTone.idle => scheme.onSurfaceVariant,
    };
    return AnimatedContainer(
      duration: AppMotion.base,
      curve: AppMotion.emphasized,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 5 : 7),
          Flexible(
            child: Transform.translate(
              offset: Offset(0, isZh ? -1.0 : -0.25),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      letterSpacing: 0.7,
                      fontSize: compact ? 8.2 : 9.5,
                      height: 1.0,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
