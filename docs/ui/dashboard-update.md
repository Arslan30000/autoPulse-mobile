# Dashboard and vehicle viewer update

- Home has one compact Connect control; Profile opens the same connection sheet.
- Live contains a large speed dial and separate RPM/coolant dials. Connection setup is absent. Recording remains connected to the existing controller.
- Tab navigation adds a local route history entry. System back and toolbar back return to Home; sheets and pushed routes close first.
- The viewer loads the bundled GLB through Flutter as a data URI, uses eager loading, and keeps a render of that same model as its poster. Each viewer has a unique ID. Shared JavaScript handles load, renderer errors, and retry in the interactive view.
- The original geometry is retained with updated paint, glass, lighting, and camera framing. Desktop platforms unsupported by `model_viewer_plus` show the rendered poster; Android, iOS, and web use the interactive renderer.

## Verification

```text
flutter --no-version-check analyze --no-pub
flutter --no-version-check test --no-pub
flutter --no-version-check build web --no-pub --no-web-resources-cdn
node tool/verify_vehicle_web.cjs
```

The browser check requires Playwright with Chromium installed. `PLAYWRIGHT_MODULE` can point to an existing Playwright or playwright-core module. It checks offline loading, scrolling over the Home car, rotation, renderer error/retry, Live navigation, and returning Home. It writes the `*-browser-390.png` previews here.

Widget previews can be updated with:

```text
flutter --no-version-check test --no-pub test/ui_refresh_test.dart --dart-define=UPDATE_UI_PREVIEWS=true
```

Android hardware rendering and a physical ELM327 connection still require device testing.

## Model

Original: “Low Poly 1970s Generic Muscle Car” by effortless, [source](https://sketchfab.com/3d-models/low-poly-1970s-generic-muscle-car-548cb08de00e4d2ba8539ca8083d768e), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

`tool/prepare_vehicle_model.py` reproduces the showroom material changes from `car.glb`; source attribution is preserved inside the derived GLB. `car-poster.png` is a transparent render of the derived model, used while loading and on unsupported desktop platforms. The model is illustrative, not a make-specific vehicle scan.
