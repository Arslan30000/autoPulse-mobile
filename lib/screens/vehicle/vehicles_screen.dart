import 'package:flutter/material.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';
import 'package:autopulse_ai/screens/vehicle/add_vehicle_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final _data = AccountDataService.instance;
  List<Vehicle> _cars = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final owner = AccountService.instance.userId;
    try {
      final cars = await _data.vehicles.list(owner);
      if (mounted && owner == AccountService.instance.userId) {
        setState(() {
          _cars = cars;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load cars. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _choose(Vehicle car) async {
    try {
      await _data.chooseVehicle(car);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not select this car.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My cars')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed:
          ObdController.instance.isRecording ||
              ObdController.instance.recordingBusy
          ? null
          : () async {
              await Navigator.push(
                context,
                MaterialPageRoute<bool>(
                  builder: (_) => const AddVehicleScreen(returnToCaller: true),
                ),
              );
              await _load();
            },
      icon: const Icon(Icons.add),
      label: const Text('Add car'),
    ),
    body: RefreshIndicator(
      onRefresh: () async {
        await _data.synchronize();
        await _load();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const Text(
            'Select a car for your next run. Stop recording before switching cars.',
          ),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null) Text(_error!),
          if (!_loading && _cars.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No cars yet. Add your first car.'),
            ),
          for (final car in _cars)
            Card(
              child: ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(car.displayName),
                subtitle: Text('${car.year}'),
                trailing: ObdController.instance.vehicle.id == car.id
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => _choose(car),
              ),
            ),
        ],
      ),
    ),
  );
}
