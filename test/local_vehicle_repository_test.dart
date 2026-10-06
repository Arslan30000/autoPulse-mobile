import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/repositories/local_vehicle_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('vehicle identities persist and remain separate between accounts and offline use', () async {
    final repository = LocalVehicleRepository();
    const vehicle = Vehicle(make: 'Synthetic', model: 'Fixture', year: 2020);
    final offline = await repository.save(vehicle, null);
    final ownerA = await repository.save(vehicle, 'owner-a');
    final ownerB = await repository.save(vehicle, 'owner-b');
    expect({offline.id, ownerA.id, ownerB.id}, hasLength(3));
    expect((await LocalVehicleRepository().load('owner-a'))!.id, ownerA.id);
    expect((await repository.save(vehicle, 'owner-a')).id, ownerA.id);
    expect(
      (await repository.save(vehicle.copyWith(model: 'Other'), 'owner-a')).id,
      isNot(ownerA.id),
    );
    expect((await repository.load(null))!.id, offline.id);
  });
}
