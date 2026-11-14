# Live diagnostic trouble codes

Open **Home → Diagnostics**, the code icon on **Live**, or the mechanic
**Diagnostics** tab. These destinations share the app's existing ELM327 connection.
The screen replaces the former mock code card with ECU results.

## Behavior

- Scans at connection and approximately every 60 seconds in the foreground.
  **Scan diagnostic codes** also requests a scan manually.
- Reads `0101` for MIL (check-engine light) status and the selected ECU's stored
  count, `03` for stored codes, `07` for pending codes, and `0A` for permanent codes.
- Uses the same serialized ELM command queue as live telemetry. A diagnostic
  scan adds four requests; it temporarily reduces telemetry sampling frequency.
- Shows each category separately, with ECU source and successful read time.
  The MIL count belongs to the selected ECU; code lists can include other ECUs.
- A dismissible app-wide banner appears when codes are first observed. Viewing
  or dismissing it suppresses repeated alerts for unchanged codes. A code can
  alert again after successful scans establish its absence and it returns.
  Detection time is the scan time, not the ECU's original fault occurrence time.
- `NO DATA`, negative responses, malformed bytes and incomplete CAN frames are
  unavailable results. They preserve previous readings with a warning rather
  than claiming an empty successful scan. Disconnection invalidates in-flight
  scans; reconnecting or selecting another vehicle resets the scan context.
- Results are held in memory for the current vehicle connection; this feature
  does not add DTC cloud synchronization or a persistent fault history.
- Only read services are enabled. Mode `04` (clear codes/readiness) remains
  blocked. Standard emissions OBD does not guarantee access to ABS/airbag/body
  modules, and a code definition is not proof that a particular part has failed.
- A small offline generic glossary is provided. Unknown/manufacturer-specific
  codes display their actual identifier and direct the user to vehicle service
  information, rather than inventing a diagnosis.

## Implementation

- `lib/models/obd_dtc.dart`: category and code model, offline glossary.
- `lib/services/obd/dtc_parser.dart`: code decoding, CAN single/multi-frame
  reassembly per ECU, legacy headerless/ISO responses, strict count validation.
  Unsupported adapter formatting is reported as unavailable.
- `lib/services/obd/dtc_monitor.dart`: scans, status retention and alert deduplication.
- `lib/services/obd/obd_controller.dart`: scan scheduling and connection lifecycle.
- `lib/screens/diagnostics/diagnostics_screen.dart`: real results and manual scans.
- `lib/core/widgets/dtc_alert_host.dart`: foreground alert above the app navigator.

## Verification

Run `flutter analyze` and `flutter test`. Focused coverage is in
`test/obd/dtc_parser_test.dart`, `dtc_monitor_test.dart`, `dtc_screen_test.dart`,
and the existing ELM/controller tests. Test replies are simulated, not car data.
They cover P/C/B/U decoding, CAN/legacy formats, multiple ECUs, interrupted
responses, explicit empty results, unsupported services, stale result retention,
connection cancellation, alert suppression/reappearance and narrow-screen UI.

Still verify with a real adapter: correct MIL state, each supported code category,
manual scan while telemetry is running, disconnect/reconnect, and banner behavior
when an ECU reports a code. Automatic alerts are foreground polling,
not instant ECU push notifications or Android background notifications.

Protocol reference: [ELM327 data sheet](https://www.elmelectronics.com/wp-content/uploads/2016/07/ELM327L_Data_Sheet.pdf),
“Interpreting Trouble Codes” and “Multiline Responses”.
