import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/health_controller.dart';
import '../models/health_record.dart';
import '../widgets/metric_card.dart';
import 'record_form_screen.dart';

/// Same side margin used on every screen so all content lines up.
const double _kPagePadding = 20;

/// VIEW – list of past health records with search/filter by date.
///
/// Layout (all aligned to the same 20px side margins):
///   [ Search by date…                     📅 ]
///   [ All | Today | 7 Days | Month | Range  ]   <- one line, full width
///   3 entries · Last 7 days        👣 1.5K 🔥 690 💧 1K
///   Today 8 Nov  ............................  totals
///   [ record card ]
class RecordListScreen extends StatelessWidget {
  const RecordListScreen({super.key});

  Future<void> _searchByDate(BuildContext context) async {
    final c = context.read<HealthController>();
    final picked = await showDatePicker(
      context: context,
      initialDate: c.filterRange?.start ?? c.today,
      firstDate: DateTime(2020),
      lastDate: c.today,
      helpText: 'Search records by date',
    );
    if (picked != null) {
      await c.setFilter(RecordFilter.specificDate, date: picked);
    }
  }

  Future<void> _pickRange(BuildContext context) async {
    final c = context.read<HealthController>();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: c.today,
      initialDateRange: c.filter == RecordFilter.customRange
          ? c.filterRange
          : DateTimeRange(
              start: DateTime(c.today.year, c.today.month, c.today.day - 13),
              end: c.today,
            ),
      helpText: 'Filter by date range',
    );
    if (range != null) {
      await c.setFilter(RecordFilter.customRange, range: range);
    }
  }

  Future<void> _delete(BuildContext context, HealthRecord record) async {
    final c = context.read<HealthController>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await c.deleteRecord(record.id!);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(deleted != null ? 'Entry deleted' : 'Could not delete entry'),
          action: deleted == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => c.restoreRecord(deleted),
                ),
        ),
      );
  }

  void _openEditor(BuildContext context, HealthRecord record) {
    Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => RecordFormScreen(record: record),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HealthController>();
    final groups = c.groupedVisibleRecords;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ------------------------------------------------------- Search --
        Padding(
          padding: const EdgeInsets.fromLTRB(
            _kPagePadding,
            4,
            _kPagePadding,
            12,
          ),
          child: _DateSearchBar(
            label: c.filter == RecordFilter.specificDate ? c.filterLabel : null,
            onTap: () => _searchByDate(context),
            onClear:
                c.filter == RecordFilter.specificDate ? c.clearFilter : null,
          ),
        ),

        // ------------------------------------------------- Filter bar --
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
          child: _FilterBar(
            selected: c.filter,
            onSelected: (filter) {
              if (filter == RecordFilter.customRange) {
                _pickRange(context);
              } else {
                c.setFilter(filter);
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        // ------------------------------------------------ Summary strip --
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kPagePadding),
          child: _SummaryStrip(
            records: c.visibleRecords,
            filterLabel: c.filterLabel,
          ),
        ),

        if (c.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              _kPagePadding,
              8,
              _kPagePadding,
              0,
            ),
            child: Text(
              c.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),

        // --------------------------------------------------------- List --
        Expanded(
          child: c.isLoading && !c.hasLoaded
              ? const Center(child: CircularProgressIndicator())
              : groups.isEmpty
                  ? _emptyState(c)
                  : RefreshIndicator(
                      onRefresh: c.loadData,
                      child: ListView.builder(
                        key: const ValueKey('records-list'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          _kPagePadding,
                          4,
                          _kPagePadding,
                          100,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final day = groups.keys.elementAt(index);
                          return _DayGroup(
                            day: day,
                            records: groups[day]!,
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

  Widget _emptyState(HealthController c) {
    if (c.isFiltering) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No records found',
        message: 'No entries match "${c.filterLabel}". '
            'Try another date or range.',
        action: OutlinedButton.icon(
          onPressed: c.clearFilter,
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

// ===================================================================
// App bar menu (used by main.dart on the Records tab)
// ===================================================================

/// ⋮ menu with data actions. Shown in the app bar on the Records tab.
class RecordsMenuButton extends StatelessWidget {
  const RecordsMenuButton({super.key});

  Future<void> _onSelected(BuildContext context, String value) async {
    final c = context.read<HealthController>();
    final messenger = ScaffoldMessenger.of(context);
    if (value == 'sample') {
      final ok = await showConfirmDialog(
        context,
        title: 'Reload sample data?',
        message: 'All current records will be replaced with demo records.',
        confirmLabel: 'Reload',
        icon: Icons.restart_alt_rounded,
      );
      if (!ok) return;
      final done = await c.resetToSampleData();
      messenger.showSnackBar(SnackBar(
        content: Text(done ? 'Sample data loaded' : 'Could not load data'),
      ));
    } else if (value == 'clear') {
      final ok = await showConfirmDialog(
        context,
        title: 'Delete all records?',
        message: 'This removes every health entry and cannot be undone.',
        confirmLabel: 'Delete all',
        destructive: true,
        icon: Icons.delete_forever_rounded,
      );
      if (!ok) return;
      final done = await c.deleteAllRecords();
      messenger.showSnackBar(SnackBar(
        content: Text(done ? 'All records deleted' : 'Could not delete records'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (v) => _onSelected(context, v),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'sample',
          child: Row(
            children: [
              Icon(Icons.restart_alt_rounded, size: 20),
              SizedBox(width: 12),
              Text('Reload sample data'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_forever_rounded, size: 20),
              SizedBox(width: 12),
              Text('Delete all records'),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// Private widgets
// ===================================================================

/// Full-width search field that opens a date picker.
class _DateSearchBar extends StatelessWidget {
  const _DateSearchBar({required this.onTap, this.label, this.onClear});

  final VoidCallback onTap;
  final String? label;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = label != null;
    return SizedBox(
      height: 52,
      child: Material(
        color: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: hasValue ? scheme.primary : scheme.outlineVariant,
            width: hasValue ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          key: const ValueKey('date-search'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label ?? 'Search by date…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                          hasValue ? scheme.onSurface : scheme.onSurfaceVariant,
                      fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (onClear != null)
                  InkWell(
                    onTap: onClear,
                    customBorder: const CircleBorder(),
                    child: const Icon(Icons.close_rounded),
                  )
                else
                  Icon(Icons.calendar_month_rounded, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One-line, full-width filter bar. Every option gets the same width and
/// labels shrink to fit, so nothing wraps or goes off screen on any phone.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});

  final RecordFilter selected;
  final ValueChanged<RecordFilter> onSelected;

  static const _options = <(RecordFilter, String)>[
    (RecordFilter.all, 'All'),
    (RecordFilter.today, 'Today'),
    (RecordFilter.last7Days, '7 Days'),
    (RecordFilter.thisMonth, 'Month'),
    (RecordFilter.customRange, 'Range'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A specific-date search is shown in the search bar, so no option here
    // is highlighted while it is active.
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          for (final (filter, label) in _options)
            Expanded(
              child: GestureDetector(
                key: ValueKey('filter-${filter.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: filter == selected
                        ? scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: filter == selected
                            ? scheme.onPrimary
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

/// "3 entries · Last 7 days" on the left, totals on the right.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.records, required this.filterLabel});

  final List<HealthRecord> records;
  final String filterLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final count =
        '${records.length} ${records.length == 1 ? 'entry' : 'entries'}';
    return SizedBox(
      height: 24,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$count · $filterLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          for (final m in HealthMetric.values) ...[
            const SizedBox(width: 10),
            Icon(
              MetricStyle.of(m).icon,
              size: 14,
              color: MetricStyle.of(m).color,
            ),
            const SizedBox(width: 2),
            Text(
              NumberUtil.compact(
                records.fold<int>(0, (sum, r) => sum + r.valueOf(m)),
              ),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetricStyle.of(m).color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Day header with totals, followed by that day's entries.
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
    final label = DateUtil.relativeLabel(day);
    final isRelative = label == 'Today' || label == 'Yesterday';
    final steps = records.fold<int>(0, (s, r) => s + r.steps);
    final water = records.fold<int>(0, (s, r) => s + r.water);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    children: [
                      if (isRelative)
                        TextSpan(
                          text: '  ${DateUtil.dayMonth(day)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  '${NumberUtil.compact(steps)} steps · '
                  '${NumberUtil.formatInt(water)} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        for (final record in records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
