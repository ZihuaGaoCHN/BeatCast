import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/platform/beatcast_gateway.dart';
import 'core/platform/beatcast_platform.dart';
import 'core/state/broadcast_controller.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

class BeatCastApp extends StatefulWidget {
  const BeatCastApp({super.key, this.gateway});

  final BeatCastGateway? gateway;

  @override
  State<BeatCastApp> createState() => _BeatCastAppState();
}

class _BeatCastAppState extends State<BeatCastApp> {
  late final BroadcastController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BroadcastController(widget.gateway ?? BeatCastPlatform());
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.dark();
    return MaterialApp(
      title: 'BeatCast',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('zh'),
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale?.languageCode == 'zh') return const Locale('zh');
        return const Locale('en');
      },
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: HomeScreen(controller: _controller),
    );
  }
}
