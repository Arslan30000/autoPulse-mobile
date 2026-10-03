# Android ELM327 Bluetooth feature

Branch: `feature/elm327-bluetooth`.

## Supported hardware and boundary

- Android phone and a paired Bluetooth Classic/SPP ELM-compatible adapter.
- The label "v1.5" normally refers to ELM firmware, not a Bluetooth transport version.
  Confirm the adapter is Classic/SPP. BLE and Wi-Fi adapters need other transports.
- No browser, iOS, background service, DTC clearing, coding, or vehicle writes.
- Recording stops when the app goes into the background or loses its connection.
- Existing health scores, reports, and chatbot screens remain prototypes.

## Architecture

`ElmBluetoothBridge.kt` uses Android BluetoothSocket and the standard SPP UUID.
Blocking connect/write calls run on a worker; a separate reader delivers events to
Flutter. Socket closure cancels blocked I/O; generation checks discard stale events.

`BluetoothTransport` is replaceable and has a test double. The Android bridge only
handles bytes and permissions, not vehicle interpretation.

`Elm327Client` buffers fragmented packets to the `>` prompt and serializes commands.
Timeouts require reconnecting so a late response cannot be assigned to another PID.
The command allowlist permits initialization settings and Mode 01 reads only.

`ObdParser` decodes units and supported-PID bitmaps. Headers identify ECU sources.
Initial selection prefers 7E8 when present, otherwise the first returned ECU; this
is not a universal guarantee of engine-ECU identity. Later readings use that same
source. Conflicting or absent replies are invalid, never converted to zero.

`ObdController` owns one app-scoped poller and shared connection state for both roles.
RPM/speed are requested every cycle; other implemented parameters are scheduled
less often. Throughput varies with hardware/protocol. Each sample has its own wall
clock request/receive timestamps and monotonic elapsed response time, not an exact
ECU acquisition timestamp. Values older than six seconds are marked stale in UI.

`SqliteObdRecordingRepository` saves sessions and per-PID samples in the app-private
`obd_recordings.db`. Missing readings have null values and explicit quality fields.
Interrupted sessions remain identifiable as incomplete. Writes are serialized;
finishing a session waits for accepted writes. No cloud upload is implemented here.

The existing owner/mechanic telemetry screens use `LiveObdView`. The Add Vehicle
screen selects an adapter; dashboard connection indicators use the real controller.

## Initial phone test

1. Power the adapter from the OBD port and pair it in Android Bluetooth settings.
   Use the adapter vendor's pairing credentials, not a guessed universal PIN.
2. Close other scanner apps that may own its connection. Test stationary with the
   ignition on; if idling the engine, use a safe, well-ventilated location.
3. Install the debug APK or run the app on the connected Android phone.
4. In Add Vehicle or Live, select Connect adapter and grant Nearby devices access.
5. Select the paired adapter. Ready is shown only after ELM initialization and an
   ECU supported-PID response. Unsupported parameters display no numeric value.
6. Check RPM/speed/temperature against an independent scanner where possible.
7. Record a short session, stop, and open Local recordings from the history icon.
8. Disconnect the adapter and verify live values stop being presented as current.
9. Reconnect, deny permission, disable Bluetooth, and background the app to verify
   each failure path. Do not perform fault injection or operate the UI while driving.

```powershell
flutter test
flutter analyze
flutter run -d DEVICE_ID --dart-define-from-file=.env
flutter build apk --debug --target-platform android-arm64 --dart-define-from-file=.env
```

The APK is `build/app/outputs/flutter-apk/app-debug.apk`. A physical adapter has not
been verified by software tests alone. Browser preview shows unsupported hardware.

## Next increments

- Add BLE using documented vendor GATT characteristics, not guessed UUIDs.
- Add authenticated, owner-scoped Supabase sync and a deliberate schema mapping.
- Add foreground-service recording only after Android lifecycle/notification design.
- Add DTC reads through the same queue; do not add clearing without explicit consent.
- Benchmark actual per-PID update rates on the available adapter and vehicle.

## References

- https://developer.android.com/develop/connectivity/bluetooth/connect-bluetooth-devices
- https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
- https://www.elmelectronics.com/wp-content/uploads/2016/07/ELM327DS.pdf
