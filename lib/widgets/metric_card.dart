import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/health_record.dart';

// Reusable UI components shared by the screens.
//
// * [MetricStyle]  – colour / icon / unit for each metric
// * [MetricCard]   – today's value of one metric with a progress ring
// * [ProgressRing] – animated circular progress indicator
// * [RecordTile]   – one health entry in a list
// * [IconBadge], [SectionHeader], [EmptyState], [showConfirmDialog]

// ===================================================================
// Metric colours & icons
// ===================================================================

/// One consistent colour per metric across the whole app:
/// steps = green, calories = red, water = blue.
class MetricStyle {
  const MetricStyle({
    required this.label,
    required this.shortLabel,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String shortLabel;
  final String unit;
  final IconData icon;
  final Color color;

  static const Color stepsColor = Color(0xFF2E9E5B);
  static const Color caloriesColor = Color(0xFFE5484D);
  static const Color waterColor = Color(0xFF2F80ED);

  static const MetricStyle steps = MetricStyle(
    label: 'Steps',
    shortLabel: 'Steps',
    unit: 'steps',
    icon: Icons.directions_walk_rounded,
    color: stepsColor,
  );

  static const MetricStyle calories = MetricStyle(
    label: 'Calories Burned',
    shortLabel: 'Calories',
    unit: 'kcal',
    icon: Icons.local_fire_department_rounded,
    color: caloriesColor,
  );

  static const MetricStyle water = MetricStyle(
    label: 'Water Intake',
    shortLabel: 'Water',
    unit: 'ml',
    icon: Icons.water_drop_rounded,
    color: waterColor,
  );

  static MetricStyle of(HealthMetric metric) {
    switch (metric) {
      case HealthMetric.steps:
        return steps;
      case HealthMetric.calories:
        return calories;
      case HealthMetric.water:
        return water;
    }
  }
}

// ===================================================================
// MetricCard
// ===================================================================

/// Shows today's value of one metric, the goal and a progress ring.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.metric,
    required this.value,
    required this.goal,
    required this.progress,
    this.onTap,
  });

  final HealthMetric metric;
  final int value;
  final int goal;
  final double progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final scheme = Theme.of(context).colorScheme;
    final reached = value >= goal;
    final remaining = goal - value;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(
                progress: progress,
                color: style.color,
                size: 56,
                strokeWidth: 6,
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      style.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            NumberUtil.formatInt(value),
                            key: ValueKey('today-${metric.name}'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          style.unit,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reached
                          ? 'Goal reached 🎉'
                          : '${NumberUtil.formatInt(remaining)} ${style.unit} '
                              'to go · goal ${NumberUtil.formatInt(goal)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: reached ? style.color : scheme.onSurfaceVariant,
                        fontWeight:
                            reached ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  color: style.color,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// ProgressRing
// ===================================================================

/// Circular progress indicator with rounded ends that animates whenever
/// [progress] changes.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 64,
    this.strokeWidth = 7,
    this.trackColor,
    this.child,
  });

  /// 0.0 – 1.0
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? color.withValues(alpha: 0.15);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, innerChild) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: color,
            trackColor: track,
            strokeWidth: strokeWidth,
          ),
          child: Center(child: innerChild),
        ),
        child: child,
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ===================================================================
// RecordTile
// ===================================================================

/// Card showing one health entry with colour-coded values.
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.showDate = false,
  });

  final HealthRecord record;
  final VoidCallback? onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDate) ...[
                      Text(
                        DateUtil.relativeLabel(record.date),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final metric in HealthMetric.values)
                          _MetricChip(
                            metric: metric,
                            value: record.valueOf(metric),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.metric, required this.value});

  final HealthMetric metric;
  final int value;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final muted = value == 0;
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : style.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${NumberUtil.formatInt(value)} ${style.unit}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// Small shared widgets
// ===================================================================

/// Rounded, tinted square holding an icon.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

/// Section title with an optional text button.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Fixed height so every section header takes the same space,
    // with or without an action button.
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Friendly placeholder for empty lists.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Material confirmation dialog. Returns `true` if confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
  IconData? icon,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: icon == null
          ? null
          : Icon(icon, color: destructive ? scheme.error : scheme.primary),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: destructive ? scheme.error : null,
            foregroundColor: destructive ? scheme.onError : null,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
