import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WatchScaffold extends StatelessWidget {
  const WatchScaffold({
    super.key,
    required this.child,
    this.useSafeArea = true,
  });

  final Widget child;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortestSide < 300;
    // Wear OS rounds the display without reporting it as a safe-area inset.
    // These values keep headers and controls inside the circle while still
    // using the wide middle of the screen for content.
    final insets = compact
        ? const EdgeInsets.fromLTRB(12, 24, 12, 20)
        : EdgeInsets.fromLTRB(
            math.max(18, shortestSide * 0.05),
            math.max(30, shortestSide * 0.10),
            math.max(18, shortestSide * 0.05),
            math.max(44, shortestSide * 0.13),
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: useSafeArea
            ? SafeArea(minimum: insets, child: child)
            : child,
      ),
    );
  }
}


class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).shortestSide < 300;
    return Padding(
      padding: EdgeInsets.fromLTRB(4, compact ? 6 : 16, 4, compact ? 3 : 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: compact ? 8.2 : null,
            ),
      ),
    );
  }
}
