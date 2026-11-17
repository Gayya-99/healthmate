import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/health_controller.dart';
import '../models/health_record.dart';
import '../widgets/metric_card.dart';

/// VIEW – form to add a new health record or edit an existing one.
///
/// Validation:
/// 1. Input formatters block letters and symbols.
/// 2. Each field must be 0 – max (e.g. steps up to 100,000).
/// 3. At least one value must be greater than 0.
/// 4. The date cannot be in the future.
class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, this.record});

  /// Record to edit, or `null` to add a new one.
  final HealthRecord? record;

  bool get isEditing => record != null;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
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
    _date = DateUtil.dateOnly(r?.date ?? DateTime.now());
  }

  @override
  void dispose() {
    _stepsController.dispose();
    _caloriesController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    if (!_isDirty || _formError != null) {
      setState(() {
        _isDirty = true;
        _formError = null;
      });
    }
  }

  Future<void> _pickDate() async {
    final today = DateUtil.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(2020),
      lastDate: today, // no future entries
      helpText: 'Select entry date',
    );
    if (picked != null && !DateUtil.isSameDay(picked, _date)) {
      setState(() {
        _date = DateUtil.dateOnly(picked);
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
    final controller = context.read<HealthController>();
    final record = HealthRecord(
      id: widget.record?.id,
      date: _date,
      steps: steps,
      calories: calories,
      water: water,
    );
    final ok = widget.isEditing
        ? await controller.updateRecord(record)
        : await controller.addRecord(record);

    if (!mounted) return;
    setState(() => _isSaving = false);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      _isDirty = false;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Entry updated' : 'Entry saved ✅'),
          ),
        );
      Navigator.of(context).pop(true);
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Something went wrong'),
        ),
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
          'The entry for ${DateUtil.mediumDate(record.date)} will be removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final controller = context.read<HealthController>();
    final messenger = ScaffoldMessenger.of(context);
    final deleted = await controller.deleteRecord(record.id!);
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
              onPressed: () => controller.restoreRecord(deleted),
            ),
          ),
        );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmDiscard() async {
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
        if (!didPop) _confirmDiscard();
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
                      : 'Record your activity. Leave a field empty if it '
                          'does not apply.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),

                // -------------------------------------------- Date field --
                InkWell(
                  key: const ValueKey('date-field'),
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: switch (DateUtil.relativeLabel(_date)) {
                        'Today' => 'Date (today)',
                        'Yesterday' => 'Date (yesterday)',
                        _ => 'Date',
                      },
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
                      DateUtil.mediumDate(_date),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ------------------------------------------ Metric fields --
                _metricField(HealthMetric.steps, _stepsController),
                const SizedBox(height: 16),
                _metricField(HealthMetric.calories, _caloriesController),
                const SizedBox(height: 16),
                _metricField(
                  HealthMetric.water,
                  _waterController,
                  quickAdd: const [250, 500, 1000],
                  last: true,
                ),

                // --------------------------------------- Form-level error --
                if (_formError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      key: const ValueKey('form-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: scheme.onErrorContainer,
                          ),
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
                const SizedBox(height: 24),

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
                        : Icon(
                            widget.isEditing
                                ? Icons.check_rounded
                                : Icons.save_rounded,
                          ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.isEditing ? 'Update Entry' : 'Save Entry',
                      ),
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

  /// Number-only field styled with the metric's colour, icon and unit.
  Widget _metricField(
    HealthMetric metric,
    TextEditingController controller, {
    List<int> quickAdd = const [],
    bool last = false,
  }) {
    final style = MetricStyle.of(metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey('field-${metric.name}'),
          controller: controller,
          onChanged: _onChanged,
          validator: Validators.metric(
            label: style.shortLabel,
            max: Validators.maxFor(metric),
          ),
          keyboardType: TextInputType.number,
          textInputAction: last ? TextInputAction.done : TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: style.label,
            hintText: '0',
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: IconBadge(icon: style.icon, color: style.color, size: 36),
            ),
            suffixText: style.unit,
            suffixStyle: TextStyle(
              color: style.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (quickAdd.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in quickAdd)
                ActionChip(
                  avatar: Icon(Icons.add_rounded, size: 16, color: style.color),
                  label: Text('$amount ${style.unit}'),
                  onPressed: () {
                    final next =
                        '${Validators.parseOrZero(controller.text) + amount}';
                    controller.value = TextEditingValue(
                      text: next,
                      selection: TextSelection.collapsed(offset: next.length),
                    );
                    _onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}
