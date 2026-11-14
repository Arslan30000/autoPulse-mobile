import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:autopulse_ai/repositories/obd_recording_repository.dart';

import 'fixtures.dart';

void main() {
  sqfliteFfiInit();
  late SqliteObdRecordingRepository store;
  setUp(() {
    store = SqliteObdRecordingRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      owner: () => null,
    );
  });
  tearDown(() => store.close());

  Future<int> add(String start, {Duration? duration, String? owner}) async {
    final id = await store.start(fixtureVehicle, fixtureDevice);
    await (await store.database).update(
      'sessions',
      {
        'started_at': start,
        'ended_at': duration == null
            ? null
            : DateTime.parse(start).add(duration).toUtc().toIso8601String(),
        'owner_id': owner,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    return id;
  }

  test(
    'newest first uses trip time even when older trips are restored later',
    () async {
      final newest = await add('2026-11-14T09:00:00Z');
      final oldest = await add('2026-11-10T09:00:00Z');
      final middle = await add('2026-11-12T09:00:00Z');
      expect((await store.listRecordings(null)).map((r) => r.id), [
        newest,
        middle,
        oldest,
      ]);
      expect(
        (await store.listRecordings(null, ascending: true)).map((r) => r.id),
        [oldest, middle, newest],
      );
    },
  );

  test(
    'dates compare actual UTC instants, including offset timestamps',
    () async {
      final later = await add('2026-11-14T06:00:00Z');
      final earlier = await add('2026-11-14T10:00:00+05:00');
      expect((await store.listRecordings(null)).map((r) => r.id), [
        later,
        earlier,
      ]);
    },
  );

  test(
    'duration sorting handles zero, long, open and invalid durations',
    () async {
      final short = await add(
        '2026-11-10T09:00:00Z',
        duration: const Duration(minutes: 2),
      );
      final open = await add('2026-11-14T09:00:00Z');
      final long = await add(
        '2026-11-11T09:00:00Z',
        duration: const Duration(hours: 28),
      );
      final zero = await add('2026-11-12T09:00:00Z', duration: Duration.zero);
      final invalid = await add(
        '2026-11-13T09:00:00Z',
        duration: const Duration(seconds: -1),
      );
      expect(
        (await store.listRecordings(
          null,
          sortBy: RecordingSortField.duration,
        )).map((r) => r.id),
        [long, short, zero, invalid, open],
      );
      expect(
        (await store.listRecordings(
          null,
          sortBy: RecordingSortField.duration,
          ascending: true,
        )).map((r) => r.id),
        [zero, short, long, open, invalid],
      );
      expect((await store.recording(long)).duration, const Duration(hours: 28));
      expect((await store.recording(open)).duration, isNull);
      expect((await store.recording(invalid)).duration, isNull);
    },
  );

  test(
    'all sort choices paginate beyond 50 without duplicates or missing ties',
    () async {
      final templateId = await add('2026-11-01T00:00:00Z');
      final db = await store.database;
      final template = (await db.query(
        'sessions',
        where: 'id = ?',
        whereArgs: [templateId],
      )).single;
      final batch = db.batch();
      for (var i = 0; i < 131; i++) {
        final start = DateTime.utc(
          2026,
          11,
          1,
        ).add(Duration(minutes: (i * 37) % 131));
        batch.insert('sessions', {
          ...template,
          'id': null,
          'cloud_id': 'sort-fixture-$i',
          'started_at': start.toIso8601String(),
          'ended_at': i % 17 == 0
              ? null
              : start.add(Duration(minutes: i % 7)).toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
      final all = await store.listRecordings(null, limit: 1000);
      for (final field in RecordingSortField.values) {
        for (final ascending in [false, true]) {
          final expected = [...all]
            ..sort((a, b) {
              final aKey = field == RecordingSortField.date
                  ? a.startedAt.microsecondsSinceEpoch
                  : a.duration?.inMilliseconds;
              final bKey = field == RecordingSortField.date
                  ? b.startedAt.microsecondsSinceEpoch
                  : b.duration?.inMilliseconds;
              if (aKey == null && bKey != null) return 1;
              if (aKey != null && bKey == null) return -1;
              var comparison = aKey == null ? 0 : aKey.compareTo(bKey!);
              if (comparison == 0) comparison = a.id.compareTo(b.id);
              return ascending ? comparison : -comparison;
            });
          final actual = <int>[];
          var cursor = 0;
          for (var pageNumber = 0; pageNumber < 5; pageNumber++) {
            final page = await store.listRecordings(
              null,
              beforeId: cursor,
              sortBy: field,
              ascending: ascending,
            );
            if (page.isEmpty) break;
            actual.addAll(page.map((r) => r.id));
            cursor = page.last.id;
          }
          expect(
            actual,
            expected.map((r) => r.id),
            reason: '$field ascending=$ascending',
          );
          expect(actual.toSet(), hasLength(132));
        }
      }
    },
  );

  test(
    'each sort keeps account isolation and rejects foreign/missing cursors',
    () async {
      final local = await add(
        '2026-11-12T09:00:00Z',
        duration: const Duration(minutes: 1),
      );
      final owned = await add(
        '2026-11-13T09:00:00Z',
        duration: const Duration(minutes: 2),
        owner: 'owner-a',
      );
      final foreign = await add(
        '2026-11-14T09:00:00Z',
        duration: const Duration(minutes: 3),
        owner: 'owner-b',
      );
      for (final field in RecordingSortField.values) {
        for (final ascending in [false, true]) {
          final visible = await store.listRecordings(
            'owner-a',
            sortBy: field,
            ascending: ascending,
          );
          expect(visible.map((r) => r.id).toSet(), {local, owned});
          expect(
            await store.listRecordings(
              'owner-a',
              sortBy: field,
              ascending: ascending,
              beforeId: foreign,
            ),
            isEmpty,
          );
          expect(
            await store.listRecordings(
              'owner-a',
              sortBy: field,
              ascending: ascending,
              beforeId: 999999,
            ),
            isEmpty,
          );
          expect(
            (await store.listRecordings(
              null,
              sortBy: field,
              ascending: ascending,
            )).single.id,
            local,
          );
        }
      }
    },
  );
}
