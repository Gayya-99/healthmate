import 'package:flutter/material.dart';

import '../../../../core/constants/health_metric.dart';
import '../../../../core/theme/metric_style.dart';
import '../../../../core/utils/date_helpers.dart';
import '../../../../core/utils/number_helpers.dart';
import '../../data/models/health_record.dart';

/// Card that shows one health entry with colour-coded metric values.
///
/// Reused on the Records list and in the dashboard "Recent activity"
/// section (reusable UI component).
class RecordTile extends StatelessWidget {
  const RecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.showDate = false,
  });

  final HealthRecord record;
  final VoidCallback? onTap;

  /// Show the date line (used where records are not grouped by day).
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDate) ...[
                      Text(
                        DateHelpers.relativeLabel(record.date),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final metric in HealthMetric.values)
                          _MetricValueChip(
                            metric: metric,
                            value: record.valueOf(metric),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricValueChip extends StatelessWidget {
  const _MetricValueChip({required this.metric, required this.value});

  final HealthMetric metric;
  final int value;

  @override
  Widget build(BuildContext context) {
    final style = MetricStyle.of(metric);
    final muted = value == 0;
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
        : style.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: muted ? 0.08 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '${NumberHelpers.formatInt(value)} ${style.unit}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
