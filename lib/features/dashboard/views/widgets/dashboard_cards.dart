import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../core/utils/number_helpers.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../viewmodel/dashboard_view_model.dart';

/// Gradient header card: overall progress, goals met and streak.
class DailyOverviewCard extends StatelessWidget {
  const DailyOverviewCard({super.key, required this.vm});

  final DashboardViewModel vm;

  @override
  Widget build(BuildContext context) {
    final percent = (vm.overallProgress * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppTheme.brandColor, AppTheme.brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandColor.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: vm.overallProgress,
            color: Colors.white,
            trackColor: Colors.white.withValues(alpha: 0.2),
            size: 92,
            strokeWidth: 9,
            child: Text(
              '$percent%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  vm.motivation,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      icon: Icons.flag_rounded,
                      text: '${vm.goalsCompleted}/3 goals',
                    ),
                    _Pill(
                      icon: Icons.local_fire_department_rounded,
                      text: vm.streak == 1
                          ? '1-day streak'
                          : '${vm.streak}-day streak',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the three "today" cards (steps / calories / water).
class MetricSummaryCard extends StatelessWidget {
  const MetricSummaryCard({
    super.key,
    required this.metric,
    required this.value,
    required this.goal,
    required this.progress,
  });

  final HealthMetric metric;
  final int value;
  final int goal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final scheme = Theme.of(context).colorScheme;
    final reached = value >= goal;
    final remaining = goal - value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ProgressRing(
              progress: progress,
              color: style.color,
              size: 62,
              strokeWidth: 7,
              child: Icon(style.icon, color: style.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          NumberHelpers.formatInt(value),
                          key: ValueKey('today-${metric.name}'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 26,
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
                        : '${NumberHelpers.formatInt(remaining)} ${style.unit} to go '
                            '· goal ${NumberHelpers.formatInt(goal)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: reached ? style.color : scheme.onSurfaceVariant,
                      fontWeight: reached ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(
                color: style.color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with one-tap buttons for logging water.
class QuickWaterCard extends StatelessWidget {
  const QuickWaterCard({
    super.key,
    required this.onAdd,
    required this.todayWater,
    required this.goal,
  });

  final ValueChanged<int> onAdd;
  final int todayWater;
  final int goal;

  @override
  Widget build(BuildContext context) {
    const style = MetricStyle.water;
    final glasses = (todayWater / 250).floor();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(icon: Icons.local_drink_rounded, color: MetricStyle.waterColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Quick add water',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$glasses glass${glasses == 1 ? '' : 'es'} today '
                        '· goal ${NumberHelpers.formatInt(goal)} ml',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final amount in AppConstants.quickWaterAmounts) ...[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: ValueKey('quick-water-$amount'),
                      style: FilledButton.styleFrom(
                        backgroundColor: style.color.withValues(alpha: 0.12),
                        foregroundColor: style.color,
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: () => onAdd(amount),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('$amount ml'),
                    ),
                  ),
                  if (amount != AppConstants.quickWaterAmounts.last)
                    const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small stat tile used in the weekly insights row.
class InsightTile extends StatelessWidget {
  const InsightTile({
    super.key,
    required this.metric,
    required this.average,
    required this.daysMet,
  });

  final HealthMetric metric;
  final int average;
  final int daysMet;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: style.icon, color: style.color, size: 32),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                NumberHelpers.formatInt(average),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'avg ${style.unit}/day',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Goal met $daysMet/7',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: style.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
