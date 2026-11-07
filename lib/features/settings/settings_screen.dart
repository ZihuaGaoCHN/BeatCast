import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/broadcast_models.dart';
import '../../core/state/broadcast_controller.dart';
import '../../l10n/app_strings.dart';
import '../../shared/widgets/watch_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final BroadcastController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = context.strings;
        final settings = controller.settings;
        final scheme = Theme.of(context).colorScheme;
        final layout = _settingsLayout(context);

        return WatchScaffold(
          useSafeArea: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              layout.side,
              layout.top,
              layout.side,
              layout.bottom,
            ),
            children: [
              _SettingsHeader(title: s.settingsTitle),
              const SizedBox(height: 8),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.bedtime_outlined,
                    accent: scheme.primary,
                    title: s.autoStopShort,
                    value: s.autoStopLabel(settings.autoStopMinutes),
                    onTap: () => _chooseAutoStop(context, s, settings),
                  ),
                  _SettingsRow(
                    icon: Icons.timelapse_rounded,
                    accent: scheme.tertiary,
                    title: s.sessionTitle,
                    value: s.sessionLabel(settings.maxSessionMinutes),
                    onTap: () => _chooseSession(context, s, settings),
                  ),
                  _SettingsRow(
                    icon: Icons.podcasts_rounded,
                    accent: scheme.secondary,
                    title: s.advertisingShort,
                    value: s.advertisingModeLabel(settings.advertisingMode),
                    onTap: () => _chooseMode(context, s, settings),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsGroup(
                children: [
                  _SettingsRow(
                    icon: Icons.settings_suggest_outlined,
                    accent: scheme.tertiary,
                    title: s.systemSettings,
                    onTap: controller.openAppSettings,
                  ),
                  _SettingsRow(
                    icon: Icons.info_outline_rounded,
                    accent: scheme.secondary,
                    title: s.aboutTitle,
                    onTap: () => _showAbout(context, s),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _chooseAutoStop(
    BuildContext context,
    AppStrings s,
    BroadcastSettings settings,
  ) async {
    final value = await _showChoices<int>(
      context,
      title: s.autoStopShort,
      options: BroadcastSettings.autoStopOptions
          .map((minutes) => _Choice(
                value: minutes,
                label: s.autoStopLabel(minutes),
              ))
          .toList(),
      selected: settings.autoStopMinutes,
    );
    if (value == null || !context.mounted) return;
    HapticFeedback.selectionClick();
    await controller.updateSettings(settings.copyWith(autoStopMinutes: value));
  }

  Future<void> _chooseSession(
    BuildContext context,
    AppStrings s,
    BroadcastSettings settings,
  ) async {
    final value = await _showChoices<int>(
      context,
      title: s.sessionShort,
      options: BroadcastSettings.sessionOptions
          .map((minutes) => _Choice(
                value: minutes,
                label: s.sessionLabel(minutes),
              ))
          .toList(),
      selected: settings.maxSessionMinutes,
    );
    if (value == null || !context.mounted) return;
    HapticFeedback.selectionClick();
    await controller.updateSettings(settings.copyWith(maxSessionMinutes: value));
  }

  Future<void> _chooseMode(
    BuildContext context,
    AppStrings s,
    BroadcastSettings settings,
  ) async {
    final value = await _showChoices<AdvertisingMode>(
      context,
      title: s.advertisingShort,
      options: [
        _Choice(
          value: AdvertisingMode.balanced,
          label: s.balanced,
          body: s.balancedBody,
        ),
        _Choice(
          value: AdvertisingMode.lowPower,
          label: s.lowPower,
          body: s.lowPowerBody,
        ),
      ],
      selected: settings.advertisingMode,
    );
    if (value == null || !context.mounted) return;
    HapticFeedback.selectionClick();
    await controller.updateSettings(settings.copyWith(advertisingMode: value));
  }

  Future<T?> _showChoices<T>(
    BuildContext context, {
    required String title,
    required List<_Choice<T>> options,
    required T selected,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => _ChoicePage<T>(
          title: title,
          options: options,
          selected: selected,
        ),
      ),
    );
  }

  void _showAbout(BuildContext context, AppStrings s) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _AboutPage(
          title: s.aboutTitle,
          body: s.aboutBody,
          version: s.versionLabel(controller.appVersion),
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Center(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 19,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.children,
    this.dividerIndent = 54,
  });

  final List<Widget> children;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Padding(
                padding: EdgeInsets.only(left: dividerIndent),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.accent,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    final row = SizedBox(
      height: 46,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Transform.translate(
                offset: Offset(0, isZh ? -1.5 : 0),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontSize: 13.5,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 82),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: text.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontSize: 9.5,
                    letterSpacing: 0.1,
                    height: 1.0,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ],
            if (value == null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: scheme.outline,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return row;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({
    required this.title,
    required this.body,
    required this.version,
  });

  final String title;
  final String body;
  final String version;

  @override
  Widget build(BuildContext context) {
    final layout = _settingsLayout(context);
    final text = Theme.of(context).textTheme;
    return WatchScaffold(
      useSafeArea: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          layout.side,
          layout.top,
          layout.side,
          layout.bottom,
        ),
        children: [
          _SettingsHeader(title: title),
          const SizedBox(height: 8),
          _SettingsGroup(
            dividerIndent: 16,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body, style: text.bodyMedium),
                    const SizedBox(height: 14),
                    Text(version, style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoicePage<T> extends StatelessWidget {
  const _ChoicePage({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<_Choice<T>> options;
  final T selected;

  @override
  Widget build(BuildContext context) {
    final layout = _settingsLayout(context);
    return WatchScaffold(
      useSafeArea: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          layout.side,
          layout.top,
          layout.side,
          layout.bottom,
        ),
        children: [
          _SettingsHeader(title: title),
          const SizedBox(height: 8),
          _SettingsGroup(
            dividerIndent: 14,
            children: [
              for (final option in options)
                _ChoiceRow<T>(
                  option: option,
                  selected: option.value == selected,
                  onTap: () => Navigator.of(context).pop(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Choice<T> {
  const _Choice({required this.value, required this.label, this.body});

  final T value;
  final String label;
  final String? body;
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _Choice<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasBody = option.body != null;
    return Material(
      color: selected
          ? scheme.secondaryContainer.withValues(alpha: 0.42)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: hasBody ? 58 : 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontSize: 13.5,
                          color: selected
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      if (hasBody) ...[
                        const SizedBox(height: 1),
                        Text(
                          option.body!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            fontSize: 9.5,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: selected ? scheme.secondary : scheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsLayout {
  const _SettingsLayout({
    required this.side,
    required this.top,
    required this.bottom,
  });

  final double side;
  final double top;
  final double bottom;
}

_SettingsLayout _settingsLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context).shortestSide;
  final compact = size < 300;
  final side = compact ? 12.0 : math.max(18.0, size * 0.05);
  final radius = size / 2;
  final halfCard = (size - side * 2) / 2;
  final circleBottomLimit =
      radius + math.sqrt(math.max(0, radius * radius - halfCard * halfCard));
  return _SettingsLayout(
    side: side,
    top: compact ? 30.0 : 36.0,
    bottom: math.max(16.0, size - circleBottomLimit + 4),
  );
}
