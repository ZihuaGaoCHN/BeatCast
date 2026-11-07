import 'package:flutter/material.dart';

import 'app_motion.dart';

abstract final class AppColors {
  static const ink = Color(0xFF08090B);
  static const inkRaised = Color(0xFF111318);
  static const coral = Color(0xFFFF6B5E);
  static const lime = Color(0xFFD8FF6A);
  static const sky = Color(0xFF9DCCFF);
  static const paper = Color(0xFFF6F1E9);
  static const muted = Color(0xFFABA8A0);
  static const line = Color(0xFF34373E);
  static const danger = Color(0xFFFFB4AB);
}

abstract final class AppTheme {
  static ThemeData dark() {
    const family = 'sans-serif';
    const scheme = ColorScheme.dark(
      primary: AppColors.coral,
      onPrimary: Color(0xFF350702),
      primaryContainer: Color(0xFF5A1A14),
      onPrimaryContainer: Color(0xFFFFDAD5),
      secondary: AppColors.lime,
      onSecondary: Color(0xFF1D2600),
      secondaryContainer: Color(0xFF364600),
      onSecondaryContainer: Color(0xFFE7FF9E),
      tertiary: AppColors.sky,
      onTertiary: Color(0xFF00344F),
      tertiaryContainer: Color(0xFF004B70),
      onTertiaryContainer: Color(0xFFCBE6FF),
      error: AppColors.danger,
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: AppColors.ink,
      onSurface: AppColors.paper,
      onSurfaceVariant: Color(0xFFC9C5BD),
      surfaceContainerLowest: Color(0xFF040506),
      surfaceContainerLow: Color(0xFF0D0E12),
      surfaceContainer: Color(0xFF13151A),
      surfaceContainerHigh: Color(0xFF1B1E24),
      surfaceContainerHighest: Color(0xFF252930),
      outline: Color(0xFF8E8B84),
      outlineVariant: AppColors.line,
      inverseSurface: AppColors.paper,
      onInverseSurface: AppColors.ink,
      inversePrimary: Color(0xFFB3261D),
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      fontFamily: family,
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
    );

    final text = base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontSize: 84,
        height: 0.9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppColors.paper,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      displayMedium: const TextStyle(
        fontSize: 58,
        height: 0.95,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: AppColors.paper,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
      headlineLarge: const TextStyle(
        fontSize: 34,
        height: 1.0,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: AppColors.paper,
      ),
      headlineMedium: const TextStyle(
        fontSize: 27,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: AppColors.paper,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: AppColors.paper,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: AppColors.paper,
      ),
      bodyLarge: const TextStyle(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: AppColors.paper,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: Color(0xFFC9C5BD),
      ),
      bodySmall: const TextStyle(
        fontSize: 11.5,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: AppColors.muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 12,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.35,
        color: AppColors.paper,
      ),
      labelMedium: const TextStyle(
        fontSize: 10.5,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: AppColors.muted,
      ),
      labelSmall: const TextStyle(
        fontSize: 9.5,
        height: 1.1,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.25,
        color: AppColors.muted,
      ),
    ).apply(fontFamily: family);

    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(40));
    final card = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

    return base.copyWith(
      textTheme: text,
      primaryTextTheme: text,
      iconTheme: const IconThemeData(color: AppColors.paper, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.paper,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: card,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: pill,
          textStyle: text.labelLarge,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: pill,
          textStyle: text.labelLarge,
          side: const BorderSide(color: AppColors.line),
          foregroundColor: AppColors.paper,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.labelLarge,
          foregroundColor: AppColors.lime,
          minimumSize: const Size(44, 44),
          shape: pill,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.paper,
          backgroundColor: scheme.surfaceContainerHigh,
          minimumSize: const Size(40, 40),
          maximumSize: const Size(44, 44),
          padding: const EdgeInsets.all(8),
          shape: const CircleBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainerLow,
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium,
        side: BorderSide.none,
        shape: pill,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.inkRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.inkRaised,
        modalBarrierColor: Color(0xCC000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.line,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: text.bodyMedium,
        behavior: SnackBarBehavior.floating,
        shape: card,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.coral,
        linearTrackColor: AppColors.line,
        circularTrackColor: AppColors.line,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: WatchPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class WatchPageTransitionsBuilder extends PageTransitionsBuilder {
  const WatchPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.965, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
