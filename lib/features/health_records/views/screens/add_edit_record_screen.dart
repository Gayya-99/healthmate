import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/health_metric.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../data/models/health_record.dart';
import '../../viewmodel/health_record_view_model.dart';
import '../widgets/metric_input_field.dart';

/// Form used to create a new entry or edit an existing one.
///
/// Validation layers:
/// 1. Input formatters stop letters and symbols being typed.
/// 2. Field validators check range (0 – max) for each metric.
/// 3. A form-level rule requires at least one value greater than 0.
/// 4. The date picker does not allow future dates.
class AddEditRecordScreen extends StatefulWidget {
  const AddEditRecordScreen({super.key, this.record, this.initialDate});

  /// The record to edit, or `null` to create a new one.
  final HealthRecord? record;

  /// Date pre-selected for a new record (defaults to today).
  final DateTime? initialDate;

  bool get isEditing => record != null;

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stepsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _waterController;
  late DateTime _date;

  bool _isSaving = false;
  bool _isDirty = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    String text(int? v) => (v == null || v == 0) ? '' : '$v';
    _stepsController = TextEditingController(text: text(r?.steps));
    _caloriesController = TextEditingController(text: text(r?.calories));
    _waterController = TextEditingController(text: text(r?.water));
    _date = DateHelpers.dateOnly(
      r?.date ?? widget.initialDate ?? DateTime.now(),
    );
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _caloriesController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _markDirty([String? _]) {
    if (!_isDirty || _formError != null) {
      setState(() {
        _isDirty = true;
        _formError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateHelpers.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today, // no future entries
      helpText: 'Select entry date',
    );
    if (picked != null && !DateHelpers.isSameDay(picked, _date)) {
      setState(() {
        _date = DateHelpers.dateOnly(picked);
        _isDirty = true;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final fieldsValid = _formKey.currentState?.validate() ?? false;

    final steps = Validators.parseOrZero(_stepsController.text);
    final calories = Validators.parseOrZero(_caloriesController.text);
    final water = Validators.parseOrZero(_waterController.text);

    final formError = Validators.atLeastOneValue(
          steps: steps,
          calories: calories,
          water: water,
        ) ??
        Validators.notInFuture(_date);

    setState(() => _formError = formError);
    if (!fieldsValid || formError != null) return;

    setState(() => _isSaving = true);
    final vm = context.read<HealthRecordViewModel>();
    final record = HealthRecord(
      id: widget.record?.id,
      date: _date,
      steps: steps,
      calories: calories,
      water: water,
    );
    final ok = widget.isEditing
        ? await vm.updateRecord(record)
        : await vm.addRecord(record);

    if (!mounted) return;
    setState(() => _isSaving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      _isDirty = false;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing ? 'Entry updated' : 'Entry saved ✅',
            ),
          ),
        );
      Navigator.of(context).pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(vm.errorMessage ?? 'Something went wrong')),
      );
    }
  }

  Future<void> _delete() async {
    final record = widget.record;
    if (record == null || record.id == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this entry?',
      message:
          'The entry for ${DateHelpers.mediumDate(record.date)} will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final vm = context.read<HealthRecordViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await vm.deleteRecord(record.id!);
    if (!mounted) return;
    if (deleted != null) {
      _isDirty = false;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Entry deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => vm.restoreRecord(deleted),
            ),
          ),
        );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _onPopBlocked() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your changes to this entry have not been saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (discard && mounted) {
      setState(() => _isDirty = false);
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope<bool>(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Entry' : 'Add Health Entry'),
          actions: [
            if (widget.isEditing)
              IconButton(
                tooltip: 'Delete entry',
                onPressed: _isSaving ? null : _delete,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
              ),
          ],
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Text(
                  widget.isEditing
                      ? 'Update the values for this entry.'
                      : 'Record the activity you want to log. '
                          'Leave a field empty if it does not apply.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // -------------------------------------------- Date field --
                _DateField(date: _date, onTap: _pickDate),
                const SizedBox(height: 16),

                MetricInputField(
                  metric: HealthMetric.steps,
                  controller: _stepsController,
                  onChanged: _markDirty,
                  validator: Validators.metric(
                    label: 'Steps',
                    max: AppConstants.maxSteps,
                  ),
                ),
                const SizedBox(height: 16),
                MetricInputField(
                  metric: HealthMetric.calories,
                  controller: _caloriesController,
                  onChanged: _markDirty,
                  validator: Validators.metric(
                    label: 'Calories',
                    max: AppConstants.maxCalories,
                  ),
                ),
                const SizedBox(height: 16),
                MetricInputField(
                  metric: HealthMetric.water,
                  controller: _waterController,
                  onChanged: _markDirty,
                  textInputAction: TextInputAction.done,
                  quickAddAmounts: const [250, 500, 1000],
                  validator: Validators.metric(
                    label: 'Water',
                    max: AppConstants.maxWaterMl,
                  ),
                ),

                // ------------------------------------- Form-level error --
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _formError == null
                      ? const SizedBox(height: 24)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Container(
                            key: const ValueKey('form-error'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    color: scheme.onErrorContainer),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formError!,
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('save-button'),
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(widget.isEditing
                            ? Icons.check_rounded
                            : Icons.save_rounded),
                    label: Text(
                      widget.isEditing ? 'Update Entry' : 'Save Entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only field that opens the date picker when tapped.
class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey('date-field'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8),
            child: IconBadge(
              icon: Icons.calendar_today_rounded,
              color: scheme.primary,
              size: 36,
            ),
          ),
          suffixIcon: const Icon(Icons.edit_calendar_rounded),
        ),
        child: Text(
          '${DateHelpers.relativeLabel(date)} · ${DateHelpers.longDate(date)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
