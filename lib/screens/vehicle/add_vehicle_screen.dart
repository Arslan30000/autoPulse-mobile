import 'package:flutter/material.dart';
import 'package:autosense_ai/core/theme/app_colors.dart';
import 'package:autosense_ai/core/theme/app_text_styles.dart';
import 'package:autosense_ai/core/widgets/primary_button.dart';
import 'package:autosense_ai/core/widgets/section_header.dart';
import 'package:autosense_ai/navigation/app_router.dart';

enum _ConnectionState { disconnected, searching, connecting, connected }

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  _ConnectionState _connectionState = _ConnectionState.disconnected;
  final _makeController = TextEditingController(text: 'Toyota');
  final _modelController = TextEditingController(text: 'Yaris');
  final _yearController = TextEditingController(text: '2020');

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _simulateConnection() async {
    setState(() => _connectionState = _ConnectionState.searching);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _connectionState = _ConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _connectionState = _ConnectionState.connected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Your Vehicle', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Connect your vehicle to start monitoring its health.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              // Vehicle fields
              Text('Make', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _makeController,
                decoration: const InputDecoration(hintText: 'Enter vehicle make'),
              ),
              const SizedBox(height: 16),
              Text('Model', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _modelController,
                decoration: const InputDecoration(hintText: 'Enter vehicle model'),
              ),
              const SizedBox(height: 16),
              Text('Year', style: AppTextStyles.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _yearController,
                decoration: const InputDecoration(hintText: 'Enter vehicle year'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              // Vehicle preview card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_makeController.text} ${_modelController.text}',
                          style: AppTextStyles.titleMedium,
                        ),
                        Text(
                          _yearController.text,
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // OBD-II Section
              const SectionHeader(title: 'OBD-II Adapter'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.bluetooth_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('ELM327', style: AppTextStyles.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildConnectionStatus(),
                    if (_connectionState == _ConnectionState.disconnected) ...[
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Connect OBD-II',
                        icon: Icons.bluetooth_searching_rounded,
                        onPressed: _simulateConnection,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_connectionState == _ConnectionState.connected)
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.main);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    switch (_connectionState) {
      case _ConnectionState.disconnected:
        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Not Connected',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
        );
      case _ConnectionState.searching:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Searching for adapter...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
        );
      case _ConnectionState.connecting:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Connecting to vehicle...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
        );
      case _ConnectionState.connected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Text(
                  'OBD-II Connected',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Vehicle ECU detected',
              style: AppTextStyles.bodySmall,
            ),
          ],
        );
    }
  }
}
