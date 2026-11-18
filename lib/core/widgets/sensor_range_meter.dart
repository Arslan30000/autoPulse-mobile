import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:autopulse_ai/models/driving_context.dart';

class SensorRangeMeter extends StatefulWidget {
  const SensorRangeMeter({
    super.key,
    required this.check,
    required this.previous,
    required this.findings,
  });

  final Map check;
  final Map previous;
  final int findings;

  @override
  State<SensorRangeMeter> createState() => _SensorRangeMeterState();
}

class _SensorRangeMeterState extends State<SensorRangeMeter> {
  String? _context;

  String _label(String key) {
    if (key == 'all') return 'Context unavailable';
    final parts = key.split(':');
    final state = DrivingState.values.firstWhere((s) => s.name == parts.first);
    return [
      state.label,
      if (parts.contains('demand')) 'High demand',
      if (parts.contains('initial')) 'First 10 min',
      if (parts.contains('later')) 'Later in drive',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ranges = widget.check['ranges'] as Map? ?? {};
    final reference = widget.check['reference_ranges'] as Map? ?? {};
    final groups =
        {
          ...ranges.keys.cast<String>(),
          ...reference.keys.cast<String>(),
        }.toList()..sort((a, b) {
          final trained =
              (reference.containsKey(b) ? 1 : 0) -
              (reference.containsKey(a) ? 1 : 0);
          return trained != 0
              ? trained
              : ((ranges[b]?['count'] as int? ?? 0) -
                    (ranges[a]?['count'] as int? ?? 0));
        });
    final selected = groups.contains(_context) ? _context : groups.firstOrNull;
    final modeled = reference[selected] as Map?;
    final recorded = ranges[selected] as Map?;
    final prior = widget.previous[selected] as Map?;
    final band = modeled ?? prior ?? recorded;
    final reading = (modeled ?? recorded)?['value'] as num?;
    final unit = widget.check['unit'] == 'C'
        ? '°C'
        : widget.check['unit'] ?? '';
    String format(num value) => value.toStringAsFixed(unit == '°C' ? 0 : 1);
    String interval(Map range) =>
        '${format(range['low'] as num)}–${format(range['high'] as num)} $unit';
    final color = widget.findings == 0
        ? theme.colorScheme.primary
        : Colors.amber;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.check['name'] as String,
              style: theme.textTheme.titleMedium,
            ),
            if (widget.findings > 0)
              Text(
                '${widget.findings} sustained findings',
                style: TextStyle(color: color),
              ),
            if (selected == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Too few valid readings to draw a range for this drive.',
                ),
              )
            else ...[
              DropdownButton<String>(
                value: selected,
                isExpanded: true,
                items: [
                  for (final group in groups)
                    DropdownMenuItem(
                      value: group,
                      child: Text(
                        _label(group),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _context = value),
              ),
              if (reading != null)
                Text(
                  '${format(reading)} $unit',
                  style: theme.textTheme.headlineSmall,
                ),
              if (band != null && reading != null) ...[
                Text(
                  modeled != null
                      ? 'Expected model range'
                      : prior != null
                      ? 'Previous drive range'
                      : 'Observed range in this drive',
                ),
                const SizedBox(height: 5),
                Text(interval(band), style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final low = (band['low'] as num).toDouble();
                    final high = (band['high'] as num).toDouble();
                    final padding = math.max((high - low) * .2, .5);
                    final min = math.min(low, reading.toDouble()) - padding;
                    final max = math.max(high, reading.toDouble()) + padding;
                    double x(num value) =>
                        (value - min) /
                        (max - min) *
                        (constraints.maxWidth - 12);
                    return Semantics(
                      label:
                          'Reading ${format(reading)} $unit. Range ${interval(band)}.',
                      child: SizedBox(
                        height: 24,
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            Positioned(
                              left: 6 + x(low),
                              width: math.max(3, x(high) - x(low)),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Positioned(
                              left: x(reading),
                              child: Container(
                                width: 12,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (prior != null && modeled != null)
                Text('Previous drive: ${interval(prior)}'),
              if (recorded != null)
                Text(
                  'This drive: ${interval(recorded)} · ${recorded['count']} readings',
                ),
            ],
          ],
        ),
      ),
    );
  }
}
