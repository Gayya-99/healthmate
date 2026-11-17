import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/health_controller.dart';
import '../models/health_record.dart';
import '../widgets/metric_card.dart';
import 'record_form_screen.dart';

/// VIEW – summary of today's activities plus weekly insights.
///
/// Example from the brief:
///   Today – 18 August 2026
///   Steps 7,850 · Calories 420 kcal · Water 2,000 ml
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSeeAllRecords});

  /// Switches the bottom navigation to the Records tab.
  final VoidCallback? onSeeAllRecords;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  HealthMetric _chartMetric = HealthMetric.steps;

  Future<void> _quickAddWater(int ml) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<HealthController>().quickAddWater(ml);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Added $ml ml of water 💧' : 'Could not add water'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _editGoal(HealthMetric metric) async {
    final controller = context.read<HealthController>();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(
        metric: metric,
        initialValue: controller.goals.valueOf(metric),
      ),
    );
    if (value != null) await controller.updateGoal(metric, value);
  }

  void _openRecord(HealthRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecordFormScreen(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HealthController>();
    final scheme = Theme.of(context).colorScheme;

    if (!c.hasLoaded && c.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final today = c.todaySummary;

    return RefreshIndicator(
      onRefresh: c.loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ------------------------------------------------------ Header --
          Text(
            DateUtil.greeting(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Today – ${DateUtil.longDate(c.today)}',
            key: const ValueKey('dashboard-date'),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),

          _OverviewCard(
            progress: c.overallProgress,
            message: c.motivation,
            goalsCompleted: c.goalsCompleted,
            streak: c.streak,
          ),
          const SizedBox(height: 20),

          // ------------------------------------------------ Today cards --
          const SectionHeader(title: 'Today\'s activity'),
          for (final metric in HealthMetric.values) ...[
            MetricCard(
              metric: metric,
              value: today.valueOf(metric),
              goal: c.goals.valueOf(metric),
              progress: c.progressFor(metric),
              onTap: () => _editGoal(metric),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap a card to change its daily goal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _QuickWaterCard(
            todayWater: today.water,
            goal: c.goals.water,
            onAdd: _quickAddWater,
          ),
          const SizedBox(height: 20),

          // ----------------------------------------------- Weekly chart --
          const SectionHeader(title: 'Last 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _MetricToggle(
                    selected: _chartMetric,
                    onChanged: (m) => setState(() => _chartMetric = m),
                  ),
                  const SizedBox(height: 16),
                  _WeeklyBarChart(
                    days: c.last7Days,
                    metric: _chartMetric,
                    goal: c.goals.valueOf(_chartMetric),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final metric in HealthMetric.values) ...[
                Expanded(
                  child: _InsightTile(
                    metric: metric,
                    average: c.weeklyAverage(metric),
                    daysMet: c.daysGoalMet(metric),
                  ),
                ),
                if (metric != HealthMetric.values.last)
                  const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // --------------------------------------------- Recent entries --
          SectionHeader(
            title: 'Recent activity',
            actionLabel: c.allRecords.isNotEmpty ? 'See all' : null,
            onAction: widget.onSeeAllRecords,
          ),
          if (c.recentRecords.isEmpty)
            const EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'No entries yet',
              message: 'Tap "Add entry" to record your first activity.',
            )
          else
            for (final record in c.recentRecords) ...[
              RecordTile(
                record: record,
                showDate: true,
                onTap: () => _openRecord(record),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

// ===================================================================
// Private dashboard widgets
// ===================================================================

/// Gradient card with overall progress, goals met and streak.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.progress,
    required this.message,
    required this.goalsCompleted,
    required this.streak,
  });

  final double progress;
  final String message;
  final int goalsCompleted;
  final int streak;

  static const Color _brand = Color(0xFF00897B);
  static const Color _brandDark = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_brand, _brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _brand.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ProgressRing(
            progress: progress,
            color: Colors.white,
            trackColor: Colors.white.withValues(alpha: 0.2),
            size: compact ? 72 : 88,
            strokeWidth: compact ? 7 : 9,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
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
                    _Pill(icon: Icons.flag_rounded, text: '$goalsCompleted/3 goals'),
                    _Pill(
                      icon: Icons.local_fire_department_rounded,
                      text: '$streak-day streak',
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

/// One-tap water logging.
class _QuickWaterCard extends StatelessWidget {
  const _QuickWaterCard({
    required this.onAdd,
    required this.todayWater,
    required this.goal,
  });

  final ValueChanged<int> onAdd;
  final int todayWater;
  final int goal;

  static const List<int> _amounts = [250, 500];

  @override
  Widget build(BuildContext context) {
    final glasses = todayWater ~/ 250;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(
                  icon: Icons.local_drink_rounded,
                  color: MetricStyle.waterColor,
                ),
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
                        '· goal ${NumberUtil.formatInt(goal)} ml',
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
                for (final amount in _amounts) ...[
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: ValueKey('quick-water-$amount'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            MetricStyle.waterColor.withValues(alpha: 0.12),
                        foregroundColor: MetricStyle.waterColor,
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: () => onAdd(amount),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$amount ml'),
                      ),
                    ),
                  ),
                  if (amount != _amounts.last) const SizedBox(width: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekly average tile.
class _InsightTile extends StatelessWidget {
  const _InsightTile({
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
                NumberUtil.formatInt(average),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              'avg ${style.unit}/day',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Goal met $daysMet/7',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

/// Three equal-width options (Steps / Calories / Water) that always fit
/// the card width – labels shrink instead of overflowing.
class _MetricToggle extends StatelessWidget {
  const _MetricToggle({required this.selected, required this.onChanged});

  final HealthMetric selected;
  final ValueChanged<HealthMetric> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final metric in HealthMetric.values)
            Expanded(
              child: GestureDetector(
                key: ValueKey('chart-${metric.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(metric),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: metric == selected
                        ? MetricStyle.of(metric).color
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      MetricStyle.of(metric).shortLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: metric == selected
                            ? Colors.white
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple bar chart of the last 7 days with a dashed goal line.
/// Built with standard widgets – no chart package needed.
class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.days,
    required this.metric,
    required this.goal,
  });

  final List<DailySummary> days;
  final HealthMetric metric;
  final int goal;

  static const double _height = 170;
  static const double _labelArea = 22;
  static const double _dayArea = 24;
  static const double _goalLabelWidth = 32;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final labelColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final maxValue =
        days.fold<int>(0, (m, d) => math.max(m, d.valueOf(metric)));
    final scaleMax = math.max(math.max(maxValue, goal), 1) * 1.1;
    const barArea = _height - _labelArea - _dayArea;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Bars get narrower on small phones instead of overflowing.
        final slot = (constraints.maxWidth - _goalLabelWidth) / days.length;
        final barWidth = (slot * 0.6).clamp(10.0, 24.0);
        return SizedBox(
          height: _height,
          child: Stack(
            children: [
              if (goal > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: _dayArea + barArea * (goal / scaleMax),
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
              Positioned.fill(
                right: _goalLabelWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final day in days)
                      Expanded(
                        child: _bar(
                          barWidth: barWidth,
                          day: day,
                          value: day.valueOf(metric),
                          height: barArea * (day.valueOf(metric) / scaleMax),
                          color: style.color,
                          labelColor: labelColor,
                          reachedGoal: goal > 0 && day.valueOf(metric) >= goal,
                          isToday: identical(day, days.last),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bar({
    required double barWidth,
    required DailySummary day,
    required int value,
    required double height,
    required Color color,
    required Color labelColor,
    required bool reachedGoal,
    required bool isToday,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: _labelArea,
          child: value > 0
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    NumberUtil.compact(value),
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
          tween: Tween(begin: 0, end: height),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (context, h, _) => Container(
            width: barWidth,
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
          height: _dayArea,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isToday ? 'Today' : DateUtil.shortDay(day.date),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? color : labelColor,
                ),
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

/// Dialog for changing a daily goal (validated).
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.metric, required this.initialValue});

  final HealthMetric metric;
  final int initialValue;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initialValue}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(int.parse(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(widget.metric);
    return AlertDialog(
      icon: Icon(style.icon, color: style.color),
      title: Text('Daily ${style.shortLabel.toLowerCase()} goal'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('goal-field'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: style.unit),
          validator: Validators.goal(
            label: style.shortLabel,
            max: Validators.maxFor(widget.metric),
          ),
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
