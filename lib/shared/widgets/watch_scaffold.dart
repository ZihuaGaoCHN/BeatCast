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

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortestSide < 300;
    return Center(
      child: SizedBox(
        width: shortestSide * (compact ? 0.66 : 0.58),
        height: compact ? 34 : 44,
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, size: compact ? 18 : 20),
              style: compact
                  ? IconButton.styleFrom(
                      minimumSize: const Size(30, 30),
                      maximumSize: const Size(30, 30),
                      padding: const EdgeInsets.all(4),
                    )
                  : null,
            ),
            SizedBox(width: compact ? 4 : 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? text.titleLarge?.copyWith(fontSize: 15)
                    : text.titleLarge,
              ),
            ),
            ?trailing,
          ],
        ),
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
