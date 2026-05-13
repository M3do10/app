import "dart:ui" show FontFeature;

import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:provider/provider.dart";

import "../models/crash_event.dart";
import "../services/crash_monitor.dart";

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fmt = DateFormat.yMMMd().add_Hms();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CrashGuard",
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Impact awareness for drivers",
              style: t.textTheme.labelMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<CrashMonitor>(
        builder: (context, m, _) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
                if (m.statusNote != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: t.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: t.colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                m.statusNote!,
                                style: t.textTheme.bodyMedium?.copyWith(
                                  color: t.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _MonitoringCard(monitor: m),
                const SizedBox(height: 20),
                _LiveSignalCard(monitor: m),
                if (m.isArming) ...[
                  const SizedBox(height: 12),
                  _ArmingBanner(remaining: m.armingRemaining),
                ],
                if (m.coolingDown) ...[
                  const SizedBox(height: 12),
                  _CooldownBanner(remaining: m.cooldownRemaining),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Text(
                      "Event log",
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    if (m.events.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Clear history"),
                              content: const Text(
                                "Remove all recorded events from this device?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel"),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    m.clearEvents();
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text("Clear"),
                                ),
                              ],
                            ),
                          );
                        },
                        child: const Text("Clear"),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (m.events.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 40,
                              color: t.colorScheme.outline,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "No events yet.",
                              textAlign: TextAlign.center,
                              style: t.textTheme.bodyLarge?.copyWith(
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  ...m.events.map((e) => _EventTile(event: e, fmt: fmt)),
                const SizedBox(height: 24),
              ],
            );
        },
      ),
    );
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.monitor});

  final CrashMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final on = monitor.monitoring;
    return Card(
      child: InkWell(
        onTap: () async {
          if (on) {
            await monitor.stop();
          } else {
            await monitor.start();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: on
                      ? t.colorScheme.primaryContainer
                      : t.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Icon(
                    on ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                    color: on
                        ? t.colorScheme.onPrimaryContainer
                        : t.colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on ? "Monitoring active" : "Monitoring paused",
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      on
                          ? "Listening for abnormal acceleration spikes."
                          : "Tap to start before your trip.",
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: on,
                onChanged: (v) async {
                  if (v) {
                    await monitor.start();
                  } else {
                    await monitor.stop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveSignalCard extends StatelessWidget {
  const _LiveSignalCard({required this.monitor});

  final CrashMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final active = monitor.monitoring;
    final scaleA = (monitor.thresholdMps2 * 2).clamp(24.0, 80.0);
    final ratioA = active
        ? (monitor.liveMagnitude / scaleA).clamp(0.0, 1.0)
        : 0.0;
    final overA = active && monitor.liveMagnitude >= monitor.thresholdMps2;
    final scaleG = (monitor.gyroThresholdRadS * 2).clamp(12.0, 50.0);
    final ratioG = active
        ? (monitor.liveGyroMagnitude / scaleG).clamp(0.0, 1.0)
        : 0.0;
    final overG = active && monitor.liveGyroMagnitude >= monitor.gyroThresholdRadS;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Acceleration",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  active
                      ? "${monitor.liveMagnitude.toStringAsFixed(1)} m/s²"
                      : "—",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: overA
                        ? t.colorScheme.error
                        : t.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratioA,
                minHeight: 10,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
                color: overA
                    ? t.colorScheme.error
                    : t.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Scale 0–${scaleA.toStringAsFixed(0)} m/s² · threshold ${monitor.thresholdMps2.toStringAsFixed(1)}",
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  "Rotation (gyroscope)",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  active
                      ? "${monitor.liveGyroMagnitude.toStringAsFixed(2)} rad/s"
                      : "—",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: overG
                        ? t.colorScheme.error
                        : t.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratioG,
                minHeight: 10,
                backgroundColor: t.colorScheme.surfaceContainerHighest,
                color: overG
                    ? t.colorScheme.error
                    : t.colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Scale 0–${scaleG.toStringAsFixed(0)} rad/s · threshold ${monitor.gyroThresholdRadS.toStringAsFixed(1)}",
              style: t.textTheme.labelSmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArmingBanner extends StatelessWidget {
  const _ArmingBanner({required this.remaining});

  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = (remaining?.inSeconds ?? 0).clamp(0, 99);
    return Material(
      color: t.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              color: t.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Stabilizing sensor · detection starts in ${s}s. Place the phone in the mount before this ends.",
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner({required this.remaining});

  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = remaining?.inSeconds ?? 0;
    return Material(
      color: t.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: t.colorScheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Cooldown active · next detection in ${s}s",
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.fmt});

  final CrashEvent event;
  final DateFormat fmt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: t.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  "Possible impact",
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  fmt.format(event.detectedAt.toLocal()),
                  style: t.textTheme.labelSmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Peak ≈ ${event.peakG.toStringAsFixed(1)} g (${event.peakMagnitudeMps2.toStringAsFixed(1)} m/s²)",
              style: t.textTheme.bodyMedium,
            ),
            if (event.peakGyroRadS != null) ...[
              const SizedBox(height: 6),
              Text(
                "Rotation peak ${event.peakGyroRadS!.toStringAsFixed(2)} rad/s",
                style: t.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            if (event.hasFix)
              SelectableText(
                "${event.position!.latitude.toStringAsFixed(6)}, ${event.position!.longitude.toStringAsFixed(6)}",
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.primary,
                ),
              )
            else
              Text(
                event.locationError ?? "Resolving location…",
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
