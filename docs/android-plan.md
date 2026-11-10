# Android plan

How an Android version of KUET Bus Live would be built on the same backend. Nothing on the server changes: both apps read and write the documents described in [data-model.md](data-model.md), under the same [`firestore.rules`](../firestore.rules).

## Stack

| Part | iOS today | Android |
|---|---|---|
| Language and UI | Swift, SwiftUI | Kotlin, Jetpack Compose (Material 3) |
| Architecture | ObservableObject view models | `ViewModel` + `StateFlow`, one repository per collection |
| Login | Firebase Auth (email/password) | Firebase Auth Android SDK, same project |
| Database | Cloud Firestore listeners | Firestore Android SDK `addSnapshotListener` / Kotlin `snapshots()` flow |
| Map | MapKit | Google Maps Compose (needs a Maps API key) or MapLibre with OpenStreetMap tiles (no key, free) |
| Road paths and ETAs | OSRM public server | the same OSRM HTTP API, called with Retrofit or Ktor |
| Push | FCM through APNs (needs a paid Apple account) | FCM directly; works without any paid account |
| Strings | String Catalog, English + Bangla | `res/values/strings.xml` and `res/values-bn/strings.xml` |
| Bangla place names | `PlaceNames.swift` | port the same table to a Kotlin `Map` |

## Mapping the iOS features

| iOS | Android |
|---|---|
| Home screen widget | Jetpack Glance app widget, reading the same small "next trip" data from DataStore |
| Live Activity / Dynamic Island | an ongoing notification (foreground service while following a bus), or Android 16's progress-centric notification style |
| Background location for drivers | a foreground service with `foregroundServiceType="location"`, `ACCESS_FINE_LOCATION` plus `ACCESS_BACKGROUND_LOCATION` asked only when a driver starts a trip |
| Face ID / passcode lock | BiometricPrompt, with the passcode hash in EncryptedSharedPreferences / Keystore |
| Arrival alert | local notification from the same ETA check |
| Smart suggestions | the scorer is pure maths: port `SuggestionScorer` and `DelayModel` to Kotlin and keep the history in Room or a JSON file |
| Account deletion | same order: re-authenticate, delete bus/places/complaints/profile, then `user.delete()` |

## Smart assistant (optional, on the phone only)

The same idea as iOS: an opt-in switch, offered only on phones that can run a built-in model, and no server at all.

- **Model:** Gemini Nano through the ML Kit GenAI APIs (AICore), available on supported phones only (recent Pixel and Galaxy flagships and others that ship AICore). Check the feature status at run time; if the phone isn't supported, hide the switch and show a short explanation, just like iOS.
- **Language:** if the model doesn't support the app's language (Bangla is likely unsupported), hide the assistant buttons with a note instead of calling anything else.
- **Same four jobs and the same checks:** rider questions answered only from the data the app passes in, complaint triage, English/Bangla announcement drafts, and timetable extraction with strict validation and a diff the admin approves. Text that doesn't fit the model's context gets "too long, paste a smaller part".
- Nothing leaves the phone.

## Order of work

1. Login, profile, approval screens, Bangla strings.
2. Map with live buses, trip card, ETA through OSRM.
3. Timetable, routes, favourite stop, My places.
4. Driver screen with the assigned bus, the location foreground service, waves banner.
5. Announcements, complaints, account deletion.
6. Widget and ongoing notification, push.
7. Smart suggestions, then the assistant.

Each step can be tested against the Firebase emulators exactly like the iOS app (`firebase emulators:start --only auth,firestore`, then point the Android SDKs at `10.0.2.2:9099` and `10.0.2.2:8080` from the Android emulator).
