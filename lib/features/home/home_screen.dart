import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/broadcast_models.dart';
import '../../core/state/broadcast_controller.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../shared/widgets/beat_button.dart';
import '../../shared/widgets/beat_ring.dart';
import '../../shared/widgets/live_badge.dart';
import '../../shared/widgets/watch_scaffold.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final BroadcastController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const _LoadingHome();
        }
        return _HomeBody(controller: controller);
      },
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.controller});

  final BroadcastController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final snapshot = controller.snapshot;
    final running = snapshot.serviceRunning;
    final hasError = controller.errorCode != null;
    final compact = MediaQuery.sizeOf(context).shortestSide < 300;

    return WatchScaffold(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              SizedBox(height: compact ? 20 : 6),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _HeartHero(
                      snapshot: snapshot,
                      size: compact ? 98 : 172,
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 2 : 4),
              _StatusRow(
                controller: controller,
                snapshot: snapshot,
              ),
              SizedBox(height: compact ? 3 : 7),
              AnimatedSize(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                alignment: Alignment.topCenter,
                child: hasError
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _ErrorCard(controller: controller),
                      )
                    : const SizedBox.shrink(),
              ),
              BeatButton(
                label: _buttonLabel(s, controller, running),
                icon: running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                tone: running ? BeatButtonTone.stop : BeatButtonTone.primary,
                busy: controller.busy,
                onPressed: () => _onPrimary(context),
              ),
              SizedBox(height: compact ? 2 : 7),
              if (!hasError && !compact)
                _Footer(
                  snapshot: snapshot,
                  compact: compact,
                  permissionsReady: controller.permissions.ready,
                ),
            ],
          ),
          _SettingsOverlay(
            compact: compact,
            onPressed: () => _openSettings(context),
          ),
        ],
      ),
    );
  }

  String _buttonLabel(
    AppStrings s,
    BroadcastController controller,
    bool running,
  ) {
    if (controller.busy) {
      return running ? s.stoppingService : s.startingService;
    }
    if (running) return s.stopBroadcast;
    if (!controller.permissions.ready) return s.setUpAndStart;
    return s.startBroadcast;
  }

  Future<void> _onPrimary(BuildContext context) async {
    if (controller.busy) return;
    HapticFeedback.selectionClick();
    if (controller.isRunning) {
      await controller.stop();
      return;
    }
    await controller.start();
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => SettingsScreen(controller: controller)),
    );
  }
}

class _SettingsOverlay extends StatelessWidget {
  const _SettingsOverlay({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).shortestSide;
    final insets = compact
        ? const EdgeInsets.fromLTRB(12, 24, 12, 20)
        : EdgeInsets.fromLTRB(
            math.max(18, screen * 0.05),
            math.max(30, screen * 0.10),
            math.max(18, screen * 0.05),
            math.max(44, screen * 0.13),
          );
    final size = compact ? 34.0 : 40.0;
    final radius = screen / 2;
    final safeRadius = radius - size / 2 - (compact ? 8 : 10);
    final angle = math.pi / 4;
    final left = radius + safeRadius * math.sin(angle) - size / 2 - insets.left;
    final top = radius - safeRadius * math.cos(angle) - size / 2 - insets.top;

    return Positioned(
      left: left,
      top: top,
      child: _SettingsButton(
        size: size,
        label: context.strings.settings,
        onPressed: onPressed,
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.size,
    required this.label,
    required this.onPressed,
  });

  final double size;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: size * 0.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeartHero extends StatelessWidget {
  const _HeartHero({required this.snapshot, required this.size});

  final BroadcastSnapshot snapshot;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = context.strings;
    final bpm = snapshot.bpm;
    final progress = bpm == null ? 0.0 : ((bpm - 40) / 160).clamp(0.0, 1.0);
    final live = snapshot.serviceRunning && snapshot.clients > 0;
    final sublabel = bpm == null
        ? (snapshot.serviceRunning ? s.waiting : s.bpm)
        : (!snapshot.contact ? s.noContact : s.bpm);

    return BeatRing(
      progress: progress,
      size: size,
      live: live,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bpm?.toString() ?? '—',
            style: text.displayLarge?.copyWith(
              fontSize: size * 0.49,
              color: bpm == null ? scheme.onSurfaceVariant : AppColors.paper,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sublabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: bpm != null && !snapshot.contact
                  ? scheme.secondary
                  : scheme.onSurfaceVariant,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.controller,
    required this.snapshot,
  });

  final BroadcastController controller;
  final BroadcastSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final (label, tone) = switch (snapshot.phase) {
      BroadcastPhase.error => (s.errorTitle, LiveBadgeTone.error),
      BroadcastPhase.live => (
          s.connectedCount(snapshot.clients),
          LiveBadgeTone.live,
        ),
      BroadcastPhase.advertising => (s.readyToPair, LiveBadgeTone.waiting),
      BroadcastPhase.starting => (s.starting, LiveBadgeTone.waiting),
      BroadcastPhase.idle => (
          controller.permissions.ready ? s.readyToPair : s.permissionsTitle,
          controller.permissions.ready ? LiveBadgeTone.idle : LiveBadgeTone.waiting,
        ),
    };
    return LiveBadge(label: label, tone: tone);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.controller});

  final BroadcastController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final scheme = Theme.of(context).colorScheme;
    final code = controller.errorCode;
    final action = switch (code) {
      'bluetooth_off' => _ErrorAction(
          icon: Icons.bluetooth_rounded,
          label: s.turnOnBluetooth,
          onTap: () => controller.requestEnableBluetooth(),
        ),
      'permissions_missing' ||
      'permissions_revoked' ||
      'background_permission' =>
        _ErrorAction(
          icon: Icons.settings_rounded,
          label: s.openSettings,
          onTap: () => controller.openAppSettings(),
        ),
      _ => _ErrorAction(
          icon: Icons.refresh_rounded,
          label: s.retry,
          onTap: () => controller.start(),
        ),
    };

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.errorFor(code),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onErrorContainer,
                    height: 1.2,
                  ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: action.label,
            onPressed: action.onTap,
            icon: Icon(action.icon, size: 17),
            style: IconButton.styleFrom(
              foregroundColor: scheme.error,
              backgroundColor: Colors.transparent,
              minimumSize: const Size(32, 32),
              maximumSize: const Size(32, 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorAction {
  const _ErrorAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.snapshot,
    required this.compact,
    required this.permissionsReady,
  });

  final BroadcastSnapshot snapshot;
  final bool compact;
  final bool permissionsReady;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          letterSpacing: 0.35,
          fontSize: compact ? 8.5 : 9.2,
        );
    if (!snapshot.serviceRunning) {
      if (!permissionsReady) {
        return Text(
          s.tapToPair,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: style,
        );
      }
      return Text(
        s.standardHr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final battery = snapshot.batteryPercent;
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 11, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(AppDurations.clock(snapshot.uptime), style: style),
        const Spacer(),
        if (battery != null) ...[
          Icon(_batteryIcon(battery), size: 12, color: AppColors.muted),
          const SizedBox(width: 3),
          Text('$battery%', style: style),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            s.screenCanSleep,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }

  IconData _batteryIcon(int percent) {
    if (percent <= 15) return Icons.battery_alert_rounded;
    if (percent <= 35) return Icons.battery_2_bar_rounded;
    if (percent <= 65) return Icons.battery_4_bar_rounded;
    return Icons.battery_full_rounded;
  }
}

class _LoadingHome extends StatelessWidget {
  const _LoadingHome();

  @override
  Widget build(BuildContext context) {
    return const WatchScaffold(
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
