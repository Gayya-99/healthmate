import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../health_records/data/models/health_record.dart';
import '../../../health_records/viewmodel/health_record_view_model.dart';
import '../../../health_records/views/screens/add_edit_record_screen.dart';
import '../../../health_records/views/widgets/record_tile.dart';
import '../../viewmodel/dashboard_view_model.dart';
import '../widgets/dashboard_cards.dart';
import '../widgets/weekly_bar_chart.dart';

/// Home screen: a summary of today's activity plus weekly insights.
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
    final ok = await context.read<HealthRecordViewModel>().quickAddWater(ml);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Added $ml ml of water 💧' : 'Could not add water'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _openRecord(BuildContext context, HealthRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => AddEditRecordScreen(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds whenever records or goals change (ProxyProvider2).
    final vm = context.watch<DashboardViewModel>();
    final recordsVm = context.watch<HealthRecordViewModel>();
    final scheme = Theme.of(context).colorScheme;

    if (!recordsVm.hasLoaded && recordsVm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: recordsVm.loadRecords,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          // ---------------------------------------------------- Header --
          Text(
            DateHelpers.greeting(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Today – ${DateHelpers.longDate(vm.today)}',
            key: const ValueKey('dashboard-date'),
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),

          DailyOverviewCard(vm: vm),
          const SizedBox(height: 20),

          // ---------------------------------------------- Today cards --
          const SectionHeader(title: 'Today\'s activity'),
          for (final metric in HealthMetric.values) ...[
            MetricSummaryCard(
              metric: metric,
              value: vm.todaySummary.valueOf(metric),
              goal: vm.goals.valueOf(metric),
              progress: vm.progressFor(metric),
            ),
            const SizedBox(height: 12),
          ],

          QuickWaterCard(
            todayWater: vm.todaySummary.water,
            goal: vm.goals.water,
            onAdd: _quickAddWater,
          ),
          const SizedBox(height: 20),

          // --------------------------------------------- Weekly chart --
          const SectionHeader(title: 'Last 7 days'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<HealthMetric>(
                      showSelectedIcon: false,
                      segments: [
                        for (final m in HealthMetric.values)
                          ButtonSegment(
                            value: m,
                            label: Text(MetricStyle.of(m).shortLabel),
                          ),
                      ],
                      selected: {_chartMetric},
                      onSelectionChanged: (s) =>
                          setState(() => _chartMetric = s.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  WeeklyBarChart(
                    days: vm.last7Days,
                    metric: _chartMetric,
                    goal: vm.goals.valueOf(_chartMetric),
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
                  child: InsightTile(
                    metric: metric,
                    average: vm.weeklyAverage(metric),
                    daysMet: vm.daysGoalMet(metric),
                  ),
                ),
                if (metric != HealthMetric.values.last)
                  const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // -------------------------------------------- Recent entries --
          SectionHeader(
            title: 'Recent activity',
            actionLabel: vm.totalRecords > 0 ? 'See all' : null,
            onAction: widget.onSeeAllRecords,
          ),
          if (vm.recentRecords.isEmpty)
            const EmptyState(
              icon: Icons.monitor_heart_outlined,
              title: 'No entries yet',
              message: 'Tap "Add entry" to record your first activity.',
            )
          else
            for (final record in vm.recentRecords) ...[
              RecordTile(
                record: record,
                showDate: true,
                onTap: () => _openRecord(context, record),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
