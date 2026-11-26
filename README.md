# neolabs-flutter

Shared Flutter foundation for the NeoLabs apps (NeoAgent, NeoRouter, NeoCloud, NeoRecall). Reusable authentication and interface components let the apps share behavior and visual design while each app owns its account state, localization and product-specific screens.

| Component | What it gives you |
|---|---|
| `NeoLabsPalette` | Shared light and dark color tokens |
| `NeoSidebarButton` | Sidebar navigation row with selection and hover states |
| `NeoSettingsLayout` | Responsive settings navigation rail and compact layout |
| `NeoSettingsGroup`, `NeoSettingsRow`, `NeoSettingsHeading`, `NeoSettingsCard` | Settings and admin sections: a heading over rows on one card |
| `NeoUpdateController`, `NeoUpdateBanner`, `NeoUpdateSettings` | Server updates from the admin pages: offer, progress across the restart, channel and log |
| `NeoCredentialFields` | Sign-in and registration fields with app-supplied validation and labels |
| `NeoForgotPasswordDialog` | Password reset dialog with input validation and request state |
| `NeoAuthBackdrop` | Shared sign-in background |
| `NeoAuthQrPlate` | QR display with preparation and empty states |
| `NeoAuthClient` | Login, registration, password reset, QR login and pairing requests using the app's transport |
| `NeoQrPolling` | QR status polling with long-poll pacing, retry backoff, pause and resume |

The host app supplies network transport, credentials, session handling, localization and application-specific routing. QR and pairing server primitives live in `neolabs-go`.

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

Licensed under AGPL-3.0, like the apps that use it.

## Desktop server installer

`package:neolabs_flutter/installer.dart` downloads an app's signed server
runtime, verifies and unpacks it, activates it and rolls back if setting it up
fails. The app describes itself with `NeoRuntimeApp`, supplies the wording and
runs its own setup step.
