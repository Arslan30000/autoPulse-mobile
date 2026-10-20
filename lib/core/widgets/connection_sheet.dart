import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/core/widgets/obd_connection_panel.dart';
import 'package:autopulse_ai/services/obd/obd_controller.dart';

Future<void> showConnectionSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bluetooth connection', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Pair your ELM327 in Android Bluetooth settings first.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              ObdConnectionPanel(controller: ObdController.instance),
            ],
          ),
        ),
      ),
    );
