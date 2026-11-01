import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/number_helpers.dart';
import '../../viewmodel/dashboard_view_model.dart';

/// Simple, dependency-free bar chart of the last 7 days for one metric.
///
/// Built from standard widgets (no chart package) so it stays light-weight
/// and fully themeable. A dashed line marks the daily goal and bars that
/// reach the goal are drawn in full colour.
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.days,
    required this.metric,
    required this.goal,
    this.height = 170,
  });

  final List<DailySummary> days;
  final HealthMetric metric;
  final int goal;
  final double height;

  static const double _labelArea = 22; // value label above each bar
  static const double _dayArea = 24; // weekday label below each bar

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final scheme = Theme.of(context).colorScheme;
    final maxValue = days.fold<int>(0, (m, d) => math.max(m, d.valueOf(metric)));
    final scaleMax = math.max(math.max(maxValue, goal), 1) * 1.1;
    final barArea = height - _labelArea - _dayArea;
    final goalY = _dayArea + barArea * (goal / scaleMax);

    return Semantics(
      label: '${style.shortLabel} for the last 7 days',
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // Goal line
            if (goal > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: goalY,
                child: Row(
                  children: [
                    Expanded(child: _DashedLine(color: style.color)),
                    const SizedBox(width: 4),
                    Text(
                      'Goal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: style.color,
                      ),
                    ),
                  ],
                ),
              ),
            // Bars
            Positioned.fill(
              right: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(
                      child: _Bar(
                        day: day,
                        value: day.valueOf(metric),
                        barHeight:
                            barArea * (day.valueOf(metric) / scaleMax),
                        color: style.color,
                        reachedGoal: goal > 0 && day.valueOf(metric) >= goal,
                        isToday: DateHelpers.isSameDay(
                          day.date,
                          days.last.date,
                        ),
                        labelColor: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.value,
    required this.barHeight,
    required this.color,
    required this.reachedGoal,
    required this.isToday,
    required this.labelColor,
  });

  final DailySummary day;
  final int value;
  final double barHeight;
  final Color color;
  final bool reachedGoal;
  final bool isToday;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: WeeklyBarChart._labelArea,
          child: value > 0
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    NumberHelpers.compact(value),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                )
              : null,
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: barHeight),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, h, _) => Container(
            width: 22,
            height: math.max(h, value > 0 ? 4 : 2),
            decoration: BoxDecoration(
              color: value == 0
                  ? labelColor.withValues(alpha: 0.15)
                  : reachedGoal
                      ? color
                      : color.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        SizedBox(
          height: WeeklyBarChart._dayArea,
          child: Center(
            child: Text(
              isToday ? 'Today' : DateHelpers.shortDay(day.date),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? color : labelColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dash,
              height: 1.5,
              margin: const EdgeInsets.only(right: gap),
              color: color.withValues(alpha: 0.7),
            ),
          ),
        );
      },
    );
  }
}
