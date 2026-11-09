# App Store privacy labels

The answers to give in **App Store Connect > App Privacy** for KUET Bus Live. They match `KUETBusLive/PrivacyInfo.xcprivacy` and the [privacy policy](privacy-policy.md). If the app starts collecting something new, update all three together.

## Privacy policy URL

```
https://github.com/shadowfax-505/KUETBusLive/blob/main/docs/privacy-policy.md
```

## Do you or your third-party partners collect data from this app?

**Yes.**

## Data types

Tick these five, and nothing else:

| Category | Data type | What it is in this app |
|---|---|---|
| Contact Info | **Name** | The name on the profile |
| Contact Info | **Email Address** | The KUET email (or a driver's email) used to sign in |
| Location | **Precise Location** | A driver's bus position while a trip is running |
| Identifiers | **User ID** | The Firebase user ID and the KUET roll, employee or driver ID |
| User Content | **Other User Content** | Favourite stop and crowd reports |

Leave everything else unticked. In particular:

- **Coarse Location:** no. Only the driver's precise position is collected.
- **Device ID:** no. The only device-level value is the Firebase push token, which is used only to deliver notifications. Firebase's own SDK privacy manifests cover what the Firebase libraries do. If App Review asks about it, ticking Device ID (App Functionality, linked, not tracking) is the cautious answer, and then add `NSPrivacyCollectedDataTypeDeviceID` to the app's privacy manifest too.
- **Usage Data, Diagnostics, Purchases, Financial Info, Health, Contacts, Browsing/Search History, Sensitive Info:** no. The app has no analytics, crash reporting, ads or payments.
- The rider's own location on the map never leaves the phone, so it is not "collected".

## Questions for each data type

Answer the same way for all five:

| Question | Answer |
|---|---|
| How is this data used? | **App Functionality** only |
| Is this data linked to the user's identity? | **Yes** |
| Is this data used for tracking? | **No** |

Why each one is App Functionality:

- **Name, Email, User ID:** signing in, checking KUET membership, and letting the transport admin approve teachers and drivers.
- **Precise Location:** showing the bus to students while the driver's trip runs. Deleted when the trip ends.
- **Other User Content:** the favourite stop drives ETAs and arrival alerts; crowd reports show how full a bus is.

## Tracking

**The app does not track users.** There is no advertising SDK, no data broker, and no IDFA. Do not add an App Tracking Transparency prompt.

## Account deletion

App Store Review asks for this separately (guideline 5.1.1(v)): accounts can be deleted in the app at **Profile > Delete account**.
