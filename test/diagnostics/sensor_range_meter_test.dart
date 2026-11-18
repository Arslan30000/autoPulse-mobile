import 'package:autopulse_ai/core/widgets/sensor_range_meter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selecting a driving condition changes the reading and range', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SensorRangeMeter(
            check: {
              'name': 'Mass airflow',
              'unit': 'g/s',
              'ranges': {
                'idling:ordinary:later': {
                  'low': 2,
                  'high': 4,
                  'value': 3,
                  'count': 40,
                },
                'cityCruising:ordinary:later': {
                  'low': 7,
                  'high': 12,
                  'value': 8,
                  'count': 20,
                },
              },
            },
            previous: {
              'cityCruising:ordinary:later': {'low': 6, 'high': 11},
            },
            findings: 0,
          ),
        ),
      ),
    );
    expect(find.text('3.0 g/s'), findsOneWidget);
    expect(find.text('Observed range in this drive'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('City Cruising · Later in drive').last);
    await tester.pumpAndSettle();
    expect(find.text('8.0 g/s'), findsOneWidget);
    expect(find.text('Previous drive range'), findsOneWidget);
    expect(find.text('6.0–11.0 g/s'), findsOneWidget);
  });
}
