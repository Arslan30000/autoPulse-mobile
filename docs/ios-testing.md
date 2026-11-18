# iPhone build and testing

Android uses the existing Bluetooth Classic transport. iPhone uses CoreBluetooth
for BLE ELM-compatible adapters that advertise one of the supported serial
services. Current profiles are FFF0 (FFF1 receive / FFF2 transmit), FFE0
(FFE1 bidirectional), and Nordic UART. Check the specific adapter and firmware.
A Classic-only serial adapter will not appear in the BLE scan.

The recording database, account restore, saved diagnostics and range meters use
the same app code on both platforms. The iOS build opens in offline mode until
an iOS Firebase app is configured.

## Sign in on iOS

1. In the existing Firebase project, register an iOS app whose bundle identifier
   matches Runner in Xcode. The current project identifier is
   `com.example.autopulse_ai`. Use a unique identifier you control when required
   by your Apple team. Use the same identifier in Firebase and Xcode.
2. Read the iOS app ID and API key from its Firebase configuration. These are
   public client identifiers. Use the API key for the iOS application.
3. On a Mac with Flutter and Xcode, select a signing team in
   `ios/Runner.xcworkspace`, connect the iPhone, and run:

```bash
flutter pub get
flutter run -d IPHONE_DEVICE_ID \
  --dart-define=FIREBASE_IOS_APP_ID=YOUR_IOS_APP_ID \
  --dart-define=FIREBASE_IOS_API_KEY=YOUR_IOS_CLIENT_API_KEY \
  --dart-define=FIREBASE_IOS_BUNDLE_ID=YOUR_RUNNER_BUNDLE_ID
```

Test email sign-in, restore a completed drive, open Vehicle Health and switch
the sensor condition dropdown. Test BLE discovery, connection, PID reads,
disconnect and save with a supported physical adapter. Windows can validate the
shared Dart code and build Android. iOS compilation, signing and BLE hardware
verification need a Mac and iPhone.

## Send it to a friend

For Android, send the signed debug APK as a **Document** in WhatsApp. The
recipient opens the file and follows Android's installation prompt. For iPhone,
use Xcode to archive and upload a signed build to App Store Connect, then send
the TestFlight invitation link over WhatsApp. External builds may require
TestFlight review. For a phone physically available to your team, use Xcode to
install a development build directly. A raw APK is an Android package.
See [Apple TestFlight](https://developer.apple.com/testflight/) and
[Apple device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).
