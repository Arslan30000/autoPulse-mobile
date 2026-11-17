import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/models/obd.dart';
import 'package:autopulse_ai/services/driving_context/context_features.dart';
import 'package:autopulse_ai/services/driving_context/context_evaluator.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

import 'helpers.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/driving_context_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test('Python and Dart agree on causal features, stabilized states, rules and forest votes', () {
    final buffer = ContextFeatureBuffer();
    final controller = DrivingContextController()..reset(connected: true);
    addTearDown(controller.dispose);
    for (final row in fixture['stream'] as List) {
      final at = DateTime.parse(row['at'] as String);
      final sample = ObdSample(
        parameter: ObdParameter.values.firstWhere((p) => p.pid == row['pid']),
        value: (row['value'] as num?)?.toDouble(),
        status: ObdSampleStatus.values.byName(row['quality'] as String),
        requestedAt: at,
        receivedAt: at,
        latencyMs: 0,
      );
      buffer.add(sample);
      controller.accept(sample);
      final features = buffer.extract(at);
      if (row['features'] == null) {
        expect(features, isNull);
      } else {
        expect(
          features!.values,
          orderedEquals(
            (row['features'] as List).map(
              (x) => closeTo((x as num).toDouble(), 1e-9),
            ),
          ),
        );
      }
      expect(controller.current.state.name, row['confirmed_state']);
    }
    for (final row in fixture['rules'] as List) {
      expect(
        const RulesContextEvaluator()
            .evaluate(
              ContextFeatures(
                (row['values'] as List)
                    .map((x) => (x as num).toDouble())
                    .toList(),
                contextEpoch,
                contextEpoch,
              ),
              DrivingState.reading,
            )
            .name,
        row['state'],
      );
    }
    final forest = ForestContextEvaluator.fromJson(
      jsonEncode(fixture['model']),
    );
    for (final row in fixture['predictions'] as List) {
      final f = ContextFeatures(
        (row['values'] as List).map((x) => (x as num).toDouble()).toList(),
        contextEpoch,
        contextEpoch,
      );
      expect(
        forest.votes(f),
        orderedEquals(
          (row['votes'] as List).map(
            (x) => closeTo((x as num).toDouble(), 1e-12),
          ),
        ),
      );
      expect(forest.evaluate(f, DrivingState.reading).name, row['state']);
    }
  });

  test('an explicitly loaded model runs on new OBD frames and changing models resets history', () {
    final forest = ForestContextEvaluator.fromJson(
      jsonEncode(fixture['model']),
    );
    final c = DrivingContextController()..reset(connected: true);
    addTearDown(c.dispose);
    c.useEvaluator(forest);
    for (var i = 0; i < 10; i++) {
      frame(c, i, speed: 100);
    }
    expect(c.current.state, DrivingState.highwayCruising);
    expect(c.current.source, ContextSource.model);
    expect(c.current.modelVersion, 'synthetic-test-only');
    c.useEvaluator(const RulesContextEvaluator());
    expect(c.current.state, DrivingState.reading);
    expect(c.current.source, ContextSource.rules);
    frame(c, 10);
    expect(c.current.state, DrivingState.reading);
  });

  test(
    'isolated speed spikes and downshifts do not become strong acceleration',
    () {
      final c = DrivingContextController()..reset(connected: true);
      addTearDown(c.dispose);
      for (var i = 0; i < 25; i++) {
        frame(
          c,
          i,
          speed: i == 12 ? 70 : 40,
          rpm: i >= 10 && i <= 14 ? 3500 : 1600,
          load: 70,
          throttle: 35,
        );
        expect(c.current.state, isNot(DrivingState.aggressiveAcceleration));
      }
      expect(c.current.state, DrivingState.cityCruising);
    },
  );

  test(
    'forest refuses unreviewed, oversized, cyclic and incompatible artifacts',
    () {
      Map<String, dynamic> model() =>
          jsonDecode(jsonEncode(fixture['model'])) as Map<String, dynamic>;
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (m) => m['reviewed_labels'] = false,
        (m) => m['features'] = ['wrong'],
        (m) => m['trees'] = [],
        (m) => m['classes'] = ['cityCruising', 'idling'],
        (m) => ((m['trees'] as List).first as List).first['left'] = 0,
      ]) {
        final m = model();
        mutate(m);
        expect(
          () => ForestContextEvaluator.fromJson(jsonEncode(m)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'missing inputs, failure, future data and stale data never become zeros',
    () {
      final buffer = ContextFeatureBuffer();
      expect(buffer.extract(contextEpoch), isNull);
      for (var i = 0; i < 4; i++) {
        for (final entry in {
          ObdParameter.speed: 36 + i * 3.6,
          ObdParameter.rpm: 1600.0,
          ObdParameter.load: 40.0,
          ObdParameter.throttle: 20.0,
        }.entries) {
          buffer.add(contextSample(entry.key, entry.value, i.toDouble()));
        }
      }
      expect(
        buffer
            .extract(contextEpoch.add(const Duration(seconds: 3)))!
            .acceleration,
        closeTo(1, 1e-9),
      );
      expect(buffer.extract(contextEpoch), isNull);
      expect(
        buffer.extract(contextEpoch.add(const Duration(seconds: 9))),
        isNull,
      );
      buffer.add(
        contextSample(
          ObdParameter.load,
          null,
          3.1,
          status: ObdSampleStatus.noData,
        ),
      );
      expect(
        buffer.extract(contextEpoch.add(const Duration(milliseconds: 3100))),
        isNull,
      );
    },
  );

  test('timer ticks and repeated speed cannot confirm a pending change', () {
    final c = DrivingContextController()..reset(connected: true);
    addTearDown(c.dispose);
    for (var i = 0; i < 4; i++) {
      frame(c, i);
    }
    expect(c.current.state, DrivingState.reading);
    for (var i = 0; i < 10; i++) {
      c.expire(contextEpoch.add(const Duration(seconds: 3)));
    }
    expect(c.current.state, DrivingState.reading);
    frame(c, 4);
    expect(c.current.state, DrivingState.cityCruising);
    expect(c.notice, isNull);
    c.expire(contextEpoch.add(const Duration(seconds: 15)));
    expect(c.current.state, DrivingState.insufficient);
  });

  test('engine off, stationary revving, ordinary/strong acceleration and deceleration', () {
    final c = DrivingContextController()..reset(connected: true);
    addTearDown(c.dispose);
    for (var i = 0; i < 10; i++) {
      frame(c, i, speed: 0, rpm: 0);
    }
    expect(c.current.state, DrivingState.engineOff);
    for (var i = 10; i < 20; i++) {
      frame(c, i, speed: 0, rpm: 4000, throttle: 80);
    }
    expect(c.current.state, DrivingState.idling);
    for (var i = 20; i < 30; i++) {
      frame(c, i, speed: 20 + (i - 20) * 2, rpm: 2200);
    }
    expect(c.current.state, DrivingState.accelerating);
    for (var i = 30; i < 40; i++) {
      frame(c, i, speed: 40 + (i - 30) * 7, rpm: 3000, load: 70, throttle: 40);
    }
    expect(c.current.state, DrivingState.aggressiveAcceleration);
    expect(c.notice?.context.state, DrivingState.aggressiveAcceleration);
    for (var i = 40; i < 50; i++) {
      frame(c, i, speed: 100 - (i - 40) * 4);
    }
    expect(c.current.state, DrivingState.decelerating);
  });

  test('high demand requires sustained evidence and resets on a new vehicle/session', () {
    final c = DrivingContextController()..reset(connected: true);
    addTearDown(c.dispose);
    for (var i = 0; i < 10; i++) {
      frame(c, i, speed: 100);
    }
    expect(c.current.state, DrivingState.highwayCruising);
    for (var i = 10; i < 14; i++) {
      frame(c, i, speed: 100, load: 90);
    }
    expect(c.current.state, DrivingState.highwayCruising);
    for (var i = 14; i < 18; i++) {
      frame(c, i, speed: 100, load: 90);
    }
    expect(c.current.state, DrivingState.heavyLoad);
    expect(c.current.highDemand, isTrue);
    expect(c.notice?.context.state, DrivingState.heavyLoad);
    c.reset(connected: true);
    expect(c.current.state, DrivingState.reading);
    expect(c.notice, isNull);
    frame(c, 18, speed: 100, load: 90);
    expect(c.current.state, DrivingState.reading);
    c.reset();
    frame(c, 19);
    expect(c.current.state, DrivingState.disconnected);
  });

  test('significant notices obey cooldown and disposal ignores late input', () {
    final c = DrivingContextController()..reset(connected: true);
    for (var i = 0; i < 10; i++) {
      frame(c, i);
    }
    for (var i = 10; i < 20; i++) {
      frame(c, i, load: 90);
    }
    final first = c.notice!.revision;
    for (var i = 20; i < 28; i++) {
      frame(c, i);
    }
    for (var i = 28; i < 36; i++) {
      frame(c, i, load: 90);
    }
    expect(c.notice!.revision, first);
    for (var i = 36; i < 44; i++) {
      frame(c, i);
    }
    for (var i = 44; i < 53; i++) {
      frame(c, i, load: 90);
    }
    expect(c.notice!.revision, greaterThan(first));
    c.dispose();
    expect(() {
      frame(c, 54);
      c.expire(contextEpoch);
      c.reset();
    }, returnsNormally);
  });
}
