import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/models/health.dart';

class VehicleIllustration extends StatefulWidget {
  final List<SystemHealth>? systems;
  final double height;
  final bool interactive;
  const VehicleIllustration({
    super.key,
    this.systems,
    this.height = 280,
    this.interactive = false,
  });

  @override
  State<VehicleIllustration> createState() => _VehicleIllustrationState();
}

class _VehicleIllustrationState extends State<VehicleIllustration> {
  static int _nextId = 0;
  late final String _id = 'autopulse-car-${_nextId++}';
  late Future<({String model, String poster, String script})> _assets;

  bool get _supported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _assets = _loadAssets();
  }

  Future<({String model, String poster, String script})> _loadAssets() async {
    if (!_supported) return (model: '', poster: '', script: '');
    final model = await rootBundle.load('assets/models/car/car-showroom.glb');
    final poster = await rootBundle.load('assets/models/car/car-poster.png');
    final script = await rootBundle.loadString('assets/vehicle_viewer.js');
    // Resolve through Flutter's bundle on every platform. A relative asset URL
    // otherwise depends on the web base path or the native viewer's HTTP proxy.
    String uri(ByteData bytes, String mime) => Uri.dataFromBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      mimeType: mime,
    ).toString();
    return (
      model: uri(model, 'model/gltf-binary'),
      poster: uri(poster, 'image/png'),
      script: script,
    );
  }

  Widget get _poster => Image.asset(
    'assets/models/car/car-poster.png',
    fit: BoxFit.contain,
    semanticLabel: 'Vehicle model preview',
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: widget.height,
    width: double.infinity,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0x332C93A5), Color(0x002C93A5)],
          radius: .7,
        ),
      ),
      child: !_supported
          ? _poster
          : FutureBuilder<({String model, String poster, String script})>(
              future: _assets,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _poster,
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: snapshot.hasError
                            ? TextButton.icon(
                                onPressed: () =>
                                    setState(() => _assets = _loadAssets()),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry 3D preview'),
                              )
                            : const LinearProgressIndicator(minHeight: 2),
                      ),
                    ],
                  );
                }
                final assets = snapshot.requireData;
                return IgnorePointer(
                  ignoring: !widget.interactive,
                  child: ModelViewer(
                    key: ValueKey('$_id-${widget.interactive}'),
                    id: _id,
                    src: assets.model,
                    poster: assets.poster,
                    loading: Loading.eager,
                    reveal: Reveal.auto,
                    alt: 'Illustrative 3D vehicle',
                    ar: false,
                    autoRotate:
                        widget.interactive &&
                        !MediaQuery.disableAnimationsOf(context),
                    autoRotateDelay: 4000,
                    rotationPerSecond: '12deg',
                    cameraControls: widget.interactive,
                    disableZoom: !widget.interactive,
                    disablePan: true,
                    touchAction: TouchAction.panY,
                    interactionPrompt: InteractionPrompt.none,
                    cameraOrbit: widget.interactive
                        ? '35deg 72deg 110%'
                        : '35deg 72deg 85%',
                    fieldOfView: '30deg',
                    minCameraOrbit: 'auto 35deg 75%',
                    maxCameraOrbit: 'auto 88deg 150%',
                    environmentImage: 'neutral',
                    exposure: 1.15,
                    shadowIntensity: .8,
                    shadowSoftness: 1,
                    backgroundColor: Colors.transparent,
                    relatedJs: kIsWeb ? null : assets.script,
                    relatedCss:
                        '''
                      #$_id { --poster-color: transparent; --progress-bar-color: #00ACC7; }
                      #$_id .vehicle-status, #$_id .vehicle-retry {
                        position: absolute; bottom: 12px; left: 50%; transform: translateX(-50%);
                        color: #B9CED5; background: #102630; border: 0; border-radius: 12px;
                        padding: 8px 12px; font: 12px sans-serif; white-space: nowrap;
                      }
                      #$_id .vehicle-retry { bottom: 48px; cursor: pointer; color: #55D5E6; }
                      ${widget.interactive ? '' : '#$_id, flt-platform-view:has(#$_id) { pointer-events: none !important; }'}
                    ''',
                    innerModelViewerHtml: '''
                      <span class="vehicle-status" aria-live="polite">Loading 3D vehicle...</span>
                      <button class="vehicle-retry" data-enabled="${widget.interactive}" type="button" hidden>Retry</button>
                    ''',
                  ),
                );
              },
            ),
    ),
  );
}

class VehiclePreviewScreen extends StatelessWidget {
  const VehiclePreviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final supported =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle model')),
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(
              child: VehicleIllustration(
                interactive: true,
                height: double.infinity,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    supported
                        ? 'Drag to rotate. Pinch to zoom.'
                        : '3D rotation is available on Android, iOS and web.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Illustrative model',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
