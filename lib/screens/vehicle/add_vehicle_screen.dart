import 'package:flutter/material.dart';
import 'package:autopulse_ai/services/account_data_service.dart';
import 'package:autopulse_ai/services/account_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/primary_button.dart';
import 'package:autopulse_ai/navigation/app_router.dart';
import 'package:autopulse_ai/models/vehicle.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

class AddVehicleScreen extends StatefulWidget {
  final bool returnToCaller;
  const AddVehicleScreen({super.key, this.returnToCaller = false});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  bool _saving = false;
  final _vehicles = AccountDataService.instance.vehicles;
  final _obd = ObdController.instance;
  final _makeController = TextEditingController(text: 'Toyota');
  final _modelController = TextEditingController(text: 'Yaris');
  final _yearController = TextEditingController(text: '2020');

  @override
  void initState() {
    super.initState();
    _obd.addListener(_refresh);
    if (!widget.returnToCaller) _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    try {
      final vehicle = await _vehicles.load(AccountService.instance.userId);
      if (!mounted || vehicle == null) return;
      setState(() {
        _makeController.text = vehicle.make;
        _modelController.text = vehicle.model;
        _yearController.text = vehicle.year.toString();
      });
    } catch (_) {
      // A missing local preference must not prevent entering vehicle details.
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _obd.removeListener(_refresh);
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving || _obd.isRecording || _obd.recordingBusy) return;
    final year = int.tryParse(_yearController.text.trim());
    if (_makeController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty ||
        year == null ||
        year < 1886 ||
        year > DateTime.now().year + 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid make, model and year.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final vehicle = await AccountDataService.instance.addVehicle(
        Vehicle(
          make: _makeController.text.trim(),
          model: _modelController.text.trim(),
          year: year,
        ),
      );
      if (!mounted) return;
      _obd.setVehicle(vehicle);
      if (widget.returnToCaller) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRouter.main,
          (_) => false,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save the vehicle. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              Text(
                'Add Your Vehicle',
                style: AppTextStyles.headlineMedium,
              ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              const SizedBox(height: 8),
              Text(
                    'Save your car now. You can connect an OBD-II adapter from the Live tab later.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .slideX(begin: -0.1),
              const SizedBox(height: 32),

              // Vehicle fields
              _buildInputLabel('Make').animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              _buildTextField(
                _makeController,
                'Enter vehicle make',
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 16),

              _buildInputLabel('Model').animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 8),
              _buildTextField(
                _modelController,
                'Enter vehicle model',
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: 16),

              _buildInputLabel('Year').animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              _buildTextField(
                _yearController,
                'Enter vehicle year',
                isNumber: true,
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: 24),

              // Vehicle preview card
              Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
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
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
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
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 500.ms)
                  .slideY(begin: 0.1),
              const SizedBox(height: 32),

              const SizedBox(height: 32),
              PrimaryButton(
                label: _saving
                    ? 'Saving vehicle?'
                    : _obd.isReady
                    ? 'Continue'
                    : 'Continue offline',
                icon: Icons.arrow_forward_rounded,
                onPressed:
                    _obd.isBusy ||
                        _saving ||
                        _obd.isRecording ||
                        _obd.recordingBusy
                    ? null
                    : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(text, style: AppTextStyles.titleSmall);
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.surfaceSecondary.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }
}
