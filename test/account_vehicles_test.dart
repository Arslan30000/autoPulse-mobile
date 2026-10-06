import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/local_vehicle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'legacy selected car survives collection migration and adding cars',
    () async {
      SharedPreferences.setMockInitialValues({
        'obd_vehicle_owner': jsonEncode({
          'id': 'legacy',
          'make': 'Toyota',
          'model': 'Yaris',
          'year': 2020,
        }),
      });
      final repo = LocalVehicleRepository();
      expect((await repo.list('owner')).single.id, 'legacy');
      final added = await repo.save(
        const Vehicle(make: 'Mitsubishi', model: 'Lancer', year: 2006),
        'owner',
      );
      expect(await repo.list('owner'), hasLength(2));
      expect((await repo.load('owner'))!.id, added.id);
      expect(await repo.pending('owner'), hasLength(2));
      await repo.select((await repo.list('owner')).first, 'owner');
      expect((await repo.load('owner'))!.id, 'legacy');
    },
  );
  test(
    'restored cloud identity survives selection and offline cache reload',
    () async {
      final repo = LocalVehicleRepository();
      const cloud = Vehicle(
        id: 'cloud-id',
        ownerId: 'a',
        make: 'Toyota',
        model: 'Yaris',
        year: 2020,
      );
      await repo.mergeCloud([cloud], 'a');
      expect((await repo.load('a'))!.id, cloud.id);
      expect(await repo.pending('a'), isEmpty);
      expect(await repo.list('b'), isEmpty);
      expect(await repo.list(null), isEmpty);
      await expectLater(repo.select(cloud, 'b'), throwsStateError);
    },
  );
  test('failed backup retains pending car across restarts', () async {
    final repo = LocalVehicleRepository();
    final car = await repo.save(
      const Vehicle(make: 'Toyota', model: 'Yaris', year: 2020),
      'a',
    );
    expect((await LocalVehicleRepository().pending('a')).single.id, car.id);
    await repo.acknowledge('a', car.id!);
    expect(await repo.pending('a'), isEmpty);
  });
}
