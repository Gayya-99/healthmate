import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/number_helpers.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../data/models/health_record.dart';
import '../../viewmodel/health_record_view_model.dart';
import '../widgets/record_tile.dart';
import 'add_edit_record_screen.dart';

/// List of all health records with search/filter by date.
///
/// * Tap the search bar to find a specific date.
/// * Filter chips give one-tap ranges (Today, Last 7 days, This month) and
///   a custom range picker.
/// * Records are grouped by day with daily totals.
/// * Swipe left to delete (with Undo); tap to edit.
class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  Future<void> _pickDate(BuildContext context) async {
    final vm = context.read<HealthRecordViewModel>();
    final picked = await showDatePicker(
      context: context,
      initialDate: vm.filterRange?.start ?? vm.today,
      firstDate: DateTime(2020),
      lastDate: vm.today,
      helpText: 'Search records by date',
    );
    if (picked != null) {
      await vm.setFilter(RecordFilter.specificDate, date: picked);
    }
  }

  Future<void> _pickRange(BuildContext context) async {
    final vm = context.read<HealthRecordViewModel>();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: vm.today,
      initialDateRange: vm.filter == RecordFilter.customRange
          ? vm.filterRange
          : DateTimeRange(
              start: DateTime(vm.today.year, vm.today.month, vm.today.day - 13),
              end: vm.today,
            ),
      helpText: 'Filter by date range',
    );
    if (range != null) {
      await vm.setFilter(RecordFilter.customRange, range: range);
    }
  }

  Future<void> _delete(BuildContext context, HealthRecord record) async {
    final vm = context.read<HealthRecordViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await vm.deleteRecord(record.id!);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(deleted != null ? 'Entry deleted' : 'Could not delete entry'),
          action: deleted == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => vm.restoreRecord(deleted),
                ),
        ),
      );
  }

  void _openEditor(BuildContext context, HealthRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => AddEditRecordScreen(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HealthRecordViewModel>();
    final groups = vm.groupedVisibleRecords;

    return Column(
      children: [
        // ---------------------------------------------------- Search bar --
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: _DateSearchBar(
            label: vm.filter == RecordFilter.specificDate
                ? vm.filterLabel
                : null,
            onTap: () => _pickDate(context),
            onClear: vm.filter == RecordFilter.specificDate
                ? vm.clearFilter
                : null,
          ),
        ),

        // -------------------------------------------------- Filter chips --
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _chip(context, vm, 'All', RecordFilter.all),
              _chip(context, vm, 'Today', RecordFilter.today),
              _chip(context, vm, 'Last 7 days', RecordFilter.last7Days),
              _chip(context, vm, 'This month', RecordFilter.thisMonth),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    vm.filter == RecordFilter.customRange
                        ? vm.filterLabel
                        : 'Custom range',
                  ),
                  selected: vm.filter == RecordFilter.customRange,
                  showCheckmark: false,
                  onSelected: (_) => _pickRange(context),
                ),
              ),
            ],
          ),
        ),

        // ------------------------------------------------ Summary strip --
        if (vm.visibleRecords.isNotEmpty)
          _SummaryStrip(records: vm.visibleRecords),

        if (vm.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(
              vm.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),

        // ---------------------------------------------------------- List --
        Expanded(
          child: vm.isLoading && !vm.hasLoaded
              ? const Center(child: CircularProgressIndicator())
              : groups.isEmpty
                  ? _buildEmpty(context, vm)
                  : RefreshIndicator(
                      onRefresh: vm.loadRecords,
                      child: ListView.builder(
                        key: const ValueKey('records-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final day = groups.keys.elementAt(index);
                          final records = groups[day]!;
                          return _DayGroup(
                            day: day,
                            records: records,
                            onTap: (r) => _openEditor(context, r),
                            onDelete: (r) => _delete(context, r),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _chip(
    BuildContext context,
    HealthRecordViewModel vm,
    String label,
    RecordFilter filter,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: vm.filter == filter,
        onSelected: (_) => vm.setFilter(filter),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, HealthRecordViewModel vm) {
    if (vm.isFiltering) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No records found',
        message: 'No entries match "${vm.filterLabel}". '
            'Try another date or range.',
        action: OutlinedButton.icon(
          onPressed: vm.clearFilter,
          icon: const Icon(Icons.filter_alt_off_rounded),
          label: const Text('Show all records'),
        ),
      );
    }
    return const EmptyState(
      icon: Icons.monitor_heart_outlined,
      title: 'No health records yet',
      message: 'Tap "Add entry" to log your steps, calories and water.',
    );
  }
}

/// Tappable "search" field that opens a date picker.
class _DateSearchBar extends StatelessWidget {
  const _DateSearchBar({required this.onTap, this.label, this.onClear});

  final VoidCallback onTap;
  final String? label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = label != null;
    return Material(
      color: Theme.of(context).inputDecorationTheme.fillColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasValue ? scheme.primary : scheme.outlineVariant,
          width: hasValue ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: const ValueKey('date-search'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label ?? 'Search by date…',
                  style: TextStyle(
                    fontSize: 15,
                    color: hasValue ? scheme.onSurface : scheme.onSurfaceVariant,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear search',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                )
              else
                Icon(Icons.calendar_month_rounded, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Totals for the records currently shown.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.records});

  final List<HealthRecord> records;

  @override
  Widget build(BuildContext context) {
    int total(HealthMetric m) =>
        records.fold(0, (sum, r) => sum + r.valueOf(m));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Text(
            '${records.length} ${records.length == 1 ? 'entry' : 'entries'}',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          for (final m in HealthMetric.values) ...[
            Icon(MetricStyle.of(m).icon, size: 14, color: MetricStyle.of(m).color),
            const SizedBox(width: 2),
            Text(
              NumberHelpers.compact(total(m)),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetricStyle.of(m).color,
              ),
            ),
            if (m != HealthMetric.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

/// Header with the day's totals followed by that day's entries.
class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.day,
    required this.records,
    required this.onTap,
    required this.onDelete,
  });

  final DateTime day;
  final List<HealthRecord> records;
  final ValueChanged<HealthRecord> onTap;
  final ValueChanged<HealthRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final water = records.fold<int>(0, (s, r) => s + r.water);
    final steps = records.fold<int>(0, (s, r) => s + r.steps);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
          child: Row(
            children: [
              Text(
                DateHelpers.relativeLabel(day),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              if (DateHelpers.relativeLabel(day).length < 10) ...[
                const SizedBox(width: 6),
                Text(
                  DateHelpers.dayMonth(day),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
              const Spacer(),
              Text(
                '${NumberHelpers.formatInt(steps)} steps · '
                '${NumberHelpers.formatInt(water)} ml',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('record-${record.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: scheme.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.delete_rounded, color: scheme.onError),
                  ],
                ),
              ),
              onDismissed: (_) => onDelete(record),
              child: RecordTile(record: record, onTap: () => onTap(record)),
            ),
          ),
      ],
    );
  }
}
