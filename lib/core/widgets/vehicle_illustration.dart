import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:autopulse_ai/models/health.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/core/theme/app_text_styles.dart';
import 'package:autopulse_ai/navigation/app_router.dart';

class VehicleIllustration extends StatelessWidget {
  final List<SystemHealth>? systems;
  final double height;

  const VehicleIllustration({super.key, this.systems, this.height = 300});

  @override
  Widget build(BuildContext context) {
    final actualHeight = height < 280 ? 280.0 : height;

    return SizedBox(
      width: double.infinity,
      height: actualHeight,
      child: ModelViewer(
        src: 'assets/models/car/car.glb', // Path to your GLB
        alt: 'A 3D model of a car',
        ar: false,
        autoRotate: true,
        cameraControls: true,
        disableZoom: false,
        backgroundColor: Colors.transparent,
        relatedCss: '''
          .Hotspot {
            background: transparent;
            border: none;
            position: relative;
            display: flex;
            justify-content: center;
            align-items: center;
            width: 12px;
            height: 12px;
            opacity: 1 !important;
            visibility: visible !important;
            pointer-events: none;
            z-index: 1000;
          }
          
          .HotspotDot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            background: #fff;
            border: 2px solid rgba(0,0,0,0.5);
            pointer-events: auto;
          }
          
          .HotspotLabel {
            position: absolute;
            background: rgba(18, 24, 33, 0.9);
            border-radius: 8px;
            color: #fff;
            padding: 6px 10px;
            font-family: sans-serif;
            font-size: 11px;
            font-weight: 600;
            letter-spacing: 0.5px;
            cursor: pointer;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.5);
            display: flex;
            align-items: center;
            gap: 6px;
            pointer-events: auto;
            white-space: nowrap;
          }
          
          .attention .HotspotDot { background: #FFB74D; box-shadow: 0 0 4px rgba(255, 183, 77, 0.4); }
          .attention .HotspotLabel { border: 1px solid rgba(255, 183, 77, 0.6); }
          .attention .icon { color: #FFB74D; }
          
          .normal .HotspotDot { background: #4CAF50; box-shadow: 0 0 4px rgba(76, 175, 80, 0.4); }
          .normal .HotspotLabel { border: 1px solid rgba(76, 175, 80, 0.6); }
          .normal .icon { color: #4CAF50; }
          
          /* Directional Offsets */
          .top-left .HotspotLabel { bottom: 20px; right: 20px; }
          .top-right .HotspotLabel { bottom: 20px; left: 20px; }
          .bottom-left .HotspotLabel { top: 20px; right: 20px; }
          .bottom-right .HotspotLabel { top: 20px; left: 20px; }
        ''',
        innerModelViewerHtml: '''
          <!-- Engine -->
          <button class="Hotspot normal top-left" slot="hotspot-engine" data-position="0.040830799653202805m 1.3518086907415063m 3.256867044588266m" data-normal="0m 0.9999999999999868m -1.629206789477422e-7m" data-visibility-attribute="visible">
            <div class="HotspotDot"></div>
            <div class="HotspotLabel" onclick="HotspotChannel.postMessage('Engine')">
              <span class="icon">✓</span> ENGINE
            </div>
          </button>
          
          <!-- Air Intake -->
          <button class="Hotspot attention bottom-left" slot="hotspot-intake" data-position="0.14165258188815155m 0.24711206863921742m 6.493449812433984m" data-normal="6.584743165990931e-9m 0.9999999999999973m -7.407025798685955e-8m" data-visibility-attribute="visible">
            <div class="HotspotDot"></div>
            <div class="HotspotLabel" onclick="HotspotChannel.postMessage('Air Intake')">
              <span class="icon">⚠</span> AIR INTAKE
            </div>
          </button>
          
          <!-- Cooling -->
          <button class="Hotspot normal top-right" slot="hotspot-cooling" data-position="2.1669508423025072m 1.5531249336564596m -0.6112901227267895m" data-normal="0.9602507802692828m 0.2791387450574244m 4.014721582212885e-9m" data-visibility-attribute="visible">
            <div class="HotspotDot"></div>
            <div class="HotspotLabel" onclick="HotspotChannel.postMessage('Cooling')">
              <span class="icon">✓</span> COOLING
            </div>
          </button>
          
          <!-- Exhaust -->
          <button class="Hotspot normal bottom-right" slot="hotspot-exhaust" data-position="1.3753960203985116m -0.6134352741216549m -6.052530475710487m" data-normal="0.06631728179261896m -0.6803960750133984m -0.7298377896779533m" data-visibility-attribute="visible">
            <div class="HotspotDot"></div>
            <div class="HotspotLabel" onclick="HotspotChannel.postMessage('Exhaust')">
              <span class="icon">✓</span> EXHAUST
            </div>
          </button>
        ''',
        javascriptChannels: {
          JavascriptChannel(
            'HotspotChannel',
            onMessageReceived: (message) {
              final component = message.message;
              SystemStatus status = SystemStatus.normal;
              Color statusColor = AppColors.success;
              IconData statusIcon = Icons.check_circle_outline_rounded;

              if (component == 'Air Intake') {
                status = SystemStatus.attention;
                statusColor = AppColors.warning;
                statusIcon = Icons.warning_amber_rounded;
              }

              _showDetailsSheet(
                context,
                component,
                status,
                statusColor,
                statusIcon,
              );
            },
          ),
        },
      ),
    );
  }

  void _showDetailsSheet(
    BuildContext context,
    String component,
    SystemStatus status,
    Color statusColor,
    IconData statusIcon,
  ) {
    final data = _getDiagnosticData(component);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Component', style: AppTextStyles.labelSmall),
                          Text(component, style: AppTextStyles.headlineMedium),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        status == SystemStatus.normal ? 'Normal' : 'Attention',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoBox(
                        'Current Reading',
                        data['reading']!,
                        statusColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoBox(
                        'Expected/Baseline',
                        data['baseline']!,
                        AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Explanation', style: AppTextStyles.titleSmall),
                const SizedBox(height: 8),
                Text(data['explanation']!, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                      left: BorderSide(color: AppColors.primary, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Insight',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data['insight']!,
                        style: AppTextStyles.bodySmall.copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.borderLight),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRouter.aiAssistant);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Ask AI',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }

  Map<String, String> _getDiagnosticData(String component) {
    switch (component) {
      case 'Air Intake':
        return {
          'reading': '0.21 g/s',
          'baseline': '2.5–4.0 g/s',
          'explanation': "Airflow behavior differs from the vehicle's historical baseline.",
          'insight': 'Possible airflow-related issue or MAF sensor contamination. Further inspection recommended.',
        };
      case 'Engine':
        return {
          'reading': '850 RPM',
          'baseline': '800–900 RPM',
          'explanation': 'Engine idling within normal parameters.',
          'insight': 'No anomalies detected in engine block telemetry. Combustion cycle is stable.',
        };
      case 'Cooling':
        return {
          'reading': '90°C',
          'baseline': '85–95°C',
          'explanation': 'Coolant temperature is stable and holding steady.',
          'insight': 'Thermostat and radiator fans are operating correctly to maintain optimal heat dissipation.',
        };
      case 'Exhaust':
        return {
          'reading': 'Normal',
          'baseline': 'Normal',
          'explanation': 'O2 sensor voltage is cycling as expected.',
          'insight': 'Catalytic converter efficiency is within limits. No rich or lean conditions detected.',
        };
      default:
        return {
          'reading': '--',
          'baseline': '--',
          'explanation': 'System operating normally.',
          'insight': 'No issues detected.',
        };
    }
  }
}
