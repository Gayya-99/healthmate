import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/health_metric.dart';
import '../../../core/theme/metric_style.dart';
import '../../../core/utils/number_helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../health_records/viewmodel/health_record_view_model.dart';
import '../viewmodel/settings_view_model.dart';

/// Daily goals, appearance and data management.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static int _maxGoal(HealthMetric m) {
    switch (m) {
      case HealthMetric.steps:
        return AppConstants.maxStepsGoal;
      case HealthMetric.calories:
        return AppConstants.maxCaloriesGoal;
      case HealthMetric.water:
        return AppConstants.maxWaterGoalMl;
    }
  }

  Future<void> _editGoal(BuildContext context, HealthMetric metric) async {
    final settings = context.read<SettingsViewModel>();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _GoalDialog(
        metric: metric,
        initialValue: settings.goals.valueOf(metric),
        max: _maxGoal(metric),
      ),
    );
    if (value != null) await settings.updateGoal(metric, value);
  }

  Future<void> _resetSample(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reload sample data?',
      message: 'All current records will be replaced with demo records.',
      confirmLabel: 'Reload',
      icon: Icons.restart_alt_rounded,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await context.read<HealthRecordViewModel>().resetToSampleData();
    messenger.showSnackBar(SnackBar(
      content: Text(done ? 'Sample data loaded' : 'Could not load sample data'),
    ));
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete all records?',
      message: 'This removes every health entry. This cannot be undone.',
      confirmLabel: 'Delete all',
      destructive: true,
      icon: Icons.delete_forever_rounded,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await context.read<HealthRecordViewModel>().deleteAllRecords();
    messenger.showSnackBar(SnackBar(
      content: Text(done ? 'All records deleted' : 'Could not delete records'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsViewModel>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // -------------------------------------------------- Daily goals --
        SectionHeader(
          title: 'Daily goals',
          actionLabel: 'Reset',
          onAction: settings.resetGoals,
        ),
        Card(
          child: Column(
            children: [
              for (final metric in HealthMetric.values) ...[
                ListTile(
                  key: ValueKey('goal-${metric.name}'),
                  leading: IconBadge(
                    icon: MetricStyle.of(metric).icon,
                    color: MetricStyle.of(metric).color,
                  ),
                  title: Text(MetricStyle.of(metric).label),
                  subtitle: Text(
                    '${NumberHelpers.formatInt(settings.goals.valueOf(metric))} '
                    '${MetricStyle.of(metric).unit} per day',
                  ),
                  trailing: const Icon(Icons.edit_rounded, size: 20),
                  onTap: () => _editGoal(context, metric),
                ),
                if (metric != HealthMetric.values.last)
                  const Divider(indent: 72),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // --------------------------------------------------- Appearance --
        const SectionHeader(title: 'Appearance'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Theme',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // --------------------------------------------------------- Data --
        const SectionHeader(title: 'Data'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: IconBadge(
                  icon: Icons.restart_alt_rounded,
                  color: scheme.primary,
                ),
                title: const Text('Reload sample data'),
                subtitle: const Text('Replace records with demo data'),
                onTap: () => _resetSample(context),
              ),
              const Divider(indent: 72),
              ListTile(
                leading: IconBadge(
                  icon: Icons.delete_forever_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  'Delete all records',
                  style: TextStyle(color: scheme.error),
                ),
                subtitle: const Text('Start with an empty history'),
                onTap: () => _clearAll(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // -------------------------------------------------------- About --
        const SectionHeader(title: 'About'),
        Card(
          child: ListTile(
            leading: IconBadge(
              icon: Icons.favorite_rounded,
              color: scheme.primary,
            ),
            title: const Text(AppConstants.appName),
            subtitle: const Text(
              '${AppConstants.appTagline}\nVersion ${AppConstants.appVersion}',
            ),
            isThreeLine: true,
          ),
        ),
      ],
    );
  }
}

/// Dialog with a validated number field for changing a goal.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    required this.metric,
    required this.initialValue,
    required this.max,
  });

  final HealthMetric metric;
  final int initialValue;
  final int max;

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
      title: Text('${style.shortLabel} goal'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('goal-field'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(suffixText: style.unit),
          validator: Validators.goal(label: style.shortLabel, max: widget.max),
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
