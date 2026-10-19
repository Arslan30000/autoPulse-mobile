import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/models/health.dart';

class VehicleIllustration extends StatelessWidget {
  final List<SystemHealth>? systems;
  final double height;
  final bool interactive;
  const VehicleIllustration({
    super.key,
    this.systems,
    this.height = 260,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: supported
          ? IgnorePointer(
              ignoring: !interactive,
              child: ModelViewer(
                key: ValueKey(interactive),
                src: kIsWeb
                    ? 'assets/assets/models/car/car-showroom.glb'
                    : 'assets/models/car/car-showroom.glb',
                alt: 'Vehicle preview in satin titanium. This illustration may differ from your selected car.',
                ar: false,
                autoRotate: false,
                cameraControls: interactive,
                disableZoom: true,
                disablePan: true,
                touchAction: TouchAction.panY,
                interactionPrompt: InteractionPrompt.none,
                cameraOrbit: '35deg 76deg 105%',
                fieldOfView: '30deg',
                minCameraOrbit: 'auto 50deg auto',
                maxCameraOrbit: 'auto 88deg auto',
                environmentImage: 'neutral',
                exposure: 1.05,
                shadowIntensity: 1.1,
                shadowSoftness: .85,
                backgroundColor: Colors.transparent,
                debugLogging: false,
                id: interactive
                    ? 'autopulse-interactive-car'
                    : 'autopulse-static-car',
                // Flutter and HTML platform views have separate hit testing.
                relatedCss: interactive
                    ? '#autopulse-interactive-car { --poster-color: transparent; touch-action: pan-y; }'
                    : '''
                      html:has(> #autopulse-static-car),
                      flt-platform-view:has(#autopulse-static-car),
                      #autopulse-static-car { pointer-events: none !important; }
                      #autopulse-static-car { --poster-color: transparent; touch-action: pan-y; }
                      ''',
                innerModelViewerHtml: '<div slot="progress-bar"></div>',
              ),
            )
          : const Center(
              child: Icon(
                Icons.directions_car_rounded,
                size: 140,
                color: AppColors.textSecondary,
              ),
            ),
    );
  }
}

class VehiclePreviewScreen extends StatelessWidget {
  const VehiclePreviewScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Explore your vehicle')),
    body: SafeArea(
      child: Column(
        children: [
          const Expanded(
            child: VehicleIllustration(
              interactive: true,
              height: double.infinity,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Drag to rotate · Illustrative vehicle model',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    ),
  );
}
