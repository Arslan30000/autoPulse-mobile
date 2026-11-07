# Accounts, cars and saved runs

See [the current backend and migration guide](free-cloud-backend.md) for the
complete architecture, security rules, deployment record and phone checklist.

Normal launches load the bundled public Supabase and Firebase identifiers:

```sh
flutter pub get
flutter run
```

Optional `.env` overrides supply `SUPABASE_URL` and `SUPABASE_ANON_KEY` (or
`SUPABASE_PUBLISHABLE_KEY`). They must target a project configured with the matching
Firebase integration and migrations. Public app settings are safe to bundle;
administrator credentials are not. Use `--dart-define=AUTOPULSE_OFFLINE=true` for
an offline-only build. The existing `.env` remains ignored by Git.

New users create a Firebase email/password account and verify its email before
cloud access. Verification and password-reset links use Firebase's hosted page;
no custom domain/SMTP is needed. Returning Supabase users register once with the
same email and enter their previous password on the verification screen. This
links the verified identity to the original UUID and preserves cars/runs. Email
equality alone never claims an old account. Later sign-ins use Firebase credentials.

An account with a car opens Home. Otherwise it opens Add Vehicle. Bluetooth can
be connected later. Settings supports profile editing, adding/selecting cars,
saved runs, sync, storage usage, connection controls and sign-out.

SQLite remains `obd_recordings.db`. Schema 3 adds durable download staging without
dropping old sessions/samples. Preferences retain account-specific and offline
cars. Signing out hides account data without deleting it. Offline runs are not
automatically assigned to the next account; their upload button asks explicitly.

Acquisition saves locally first. Full chunks of an owned active run can back up
while recording; the final tail uploads after stopping. Sync runs in the foreground,
on a timer/resume and through manual retry. Internet is required for cloud access,
not Bluetooth recording, graphs or CSV export. Only completed cloud runs restore
to another phone. Downloads validate pages into SQLite staging and publish only
a complete trip; interruptions resume from durable checkpoints.

Install updates with the same package ID and signing certificate. Do not uninstall
or clear storage before exporting unsynced runs. Do not downgrade to a binary that
cannot open schema 3. Keep the app visible and screen awake when recording.
