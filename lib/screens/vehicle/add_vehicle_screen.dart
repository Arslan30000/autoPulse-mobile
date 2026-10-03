import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/core/widgets/section_header.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

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
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Your Vehicle', style: AppTextStyles.headlineMedium).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                'Connect your vehicle to start monitoring its health.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideX(begin: -0.1),
              const SizedBox(height: 32),
              
              // Vehicle fields
              _buildInputLabel('Make').animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              _buildTextField(_makeController, 'Enter vehicle make').animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 16),
              
              _buildInputLabel('Model').animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 8),
              _buildTextField(_modelController, 'Enter vehicle model').animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 16),
              
              _buildInputLabel('Year').animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              _buildTextField(_yearController, 'Enter vehicle year', isNumber: true).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 24),
              
              // Vehicle preview card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGlow.withValues(alpha: 0.05),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.1),
              const SizedBox(height: 32),
              
              // OBD-II Section
              const SectionHeader(title: 'OBD-II Adapter').animate().fadeIn(delay: 600.ms),
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _connectionState == _ConnectionState.connected 
                        ? AppColors.success.withValues(alpha: 0.5) 
                        : AppColors.border,
                  ),
                  boxShadow: _connectionState == _ConnectionState.connected ? [
                    BoxShadow(
                      color: AppColors.success.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 1,
                    )
                  ] : [],
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
                    const SizedBox(height: 16),
                    _buildConnectionStatus(),
                    if (_connectionState == _ConnectionState.disconnected) ...[
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Connect OBD-II',
                        icon: Icons.bluetooth_searching_rounded,
                        onPressed: _simulateConnection,
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 700.ms).slideY(begin: 0.1),
              const SizedBox(height: 32),
              
              if (_connectionState == _ConnectionState.connected)
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, AppRouter.main);
                  },
                ).animate().fadeIn().scale(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(text, style: AppTextStyles.titleSmall);
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surfaceSecondary.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
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
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
                boxShadow: [
                  BoxShadow(color: AppColors.danger.withValues(alpha: 0.5), blurRadius: 8)
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Not Connected',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
            ),
          ],
        );
      case _ConnectionState.searching:
      case _ConnectionState.connecting:
        return Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _connectionState == _ConnectionState.searching ? 'Searching for adapter...' : 'Connecting to vehicle...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
        ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1500.ms);
      case _ConnectionState.connected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'OBD-II Connected',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success),
                ),
              ],
            ).animate().fadeIn().slideX(),
            const SizedBox(height: 6),
            Text(
              'Vehicle ECU detected',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ).animate().fadeIn(delay: 200.ms),
          ],
        );
    }
  }
}
