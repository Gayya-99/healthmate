import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../shared/widgets/common_widgets.dart';

/// Number-only text field styled for one health metric.
///
/// * Shows the metric's colour, icon and unit.
/// * Opens the numeric keyboard and blocks non-digit characters.
/// * Validation is supplied by the parent form (see `Validators.metric`).
class MetricInputField extends StatelessWidget {
  const MetricInputField({
    super.key,
    required this.metric,
    required this.controller,
    required this.validator,
    this.helperText,
    this.textInputAction = TextInputAction.next,
    this.quickAddAmounts = const [],
    this.onChanged,
  });

  final HealthMetric metric;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final String? helperText;
  final TextInputAction textInputAction;

  /// Optional "+250" style chips that add to the current value.
  final List<int> quickAddAmounts;
  final ValueChanged<String>? onChanged;

  void _addAmount(int amount) {
    final current = int.tryParse(controller.text.trim()) ?? 0;
    final next = '${current + amount}';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey('field-${metric.name}'),
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textInputAction: textInputAction,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: style.label,
            hintText: '0',
            helperText: helperText,
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
        if (quickAddAmounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final amount in quickAddAmounts)
                ActionChip(
                  avatar: Icon(Icons.add_rounded, size: 16, color: style.color),
                  label: Text('$amount ${style.unit}'),
                  onPressed: () => _addAmount(amount),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
