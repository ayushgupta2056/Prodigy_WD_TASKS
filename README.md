# Booking & Profit Manager

Your own central record for a homestay listed on **Airbnb, MakeMyTrip, Goibibo,
Agoda and Booking.com**. Booking and cancellation emails are read from your
Gmail into a Google Sheet, and the **Windows** and **Android** apps show one
calendar, your real **in-hand earnings**, profit and insights.

The app never changes anything on the platforms.

```
Gmail ──(every 5 min)──▶ Google Apps Script ──▶ Google Sheet
                                   ▲
                                   │ JSON API (secret key)
                     ┌─────────────┴─────────────┐
                Windows app                  Android app
          (works offline, syncs edits when back online)
```

| Folder | What it is |
|---|---|
| [`apps-script/`](apps-script) | The backend that runs in your Google account. Set it up with **[SETUP.md](apps-script/SETUP.md)**. |
| [`app/`](app) | The Flutter app (one codebase for Windows and Android). |
| [`samples/`](samples) | Anonymised sample emails the parsers are built and tested against. |
| [`.github/workflows/`](.github/workflows) | Builds the `.exe` and `.apk` automatically. |

---

## 1. Set up the backend (once)

Follow **[apps-script/SETUP.md](apps-script/SETUP.md)**. It takes about 10 minutes
and ends with a **Web App URL** and an **API key** to paste into the apps.

## 2. Download the apps

Every successful build is published on the **Releases** page with the same
file names, so these links always download the newest version:

- **Android:** https://github.com/ayushgupta2056/Prodigy_WD_TASKS/releases/latest/download/BookingManager.apk
  (open this link on your phone)
- **Windows installer:** https://github.com/ayushgupta2056/Prodigy_WD_TASKS/releases/latest/download/BookingManager-Setup.exe
- **Windows portable (no install):** https://github.com/ayushgupta2056/Prodigy_WD_TASKS/releases/latest/download/BookingManager-Windows-portable.zip

No GitHub sign-in is needed. If your PC calls the `.apk` a "BlueStacks APK",
that's only because BlueStacks is installed on the PC: it's a normal Android
file. Copy it to the phone, or simply open the Android link on the phone.

## 3. Install on Windows

**Installer (recommended)**

1. Double-click `BookingManager-Setup.exe`.
2. Windows may show **"Windows protected your PC"**, because the installer
   isn't code-signed. Click **More info → Run anyway**.
3. Click through the installer. It installs just for you and needs no admin
   rights. Tick *Create a desktop shortcut* if you want one.
4. Open **Booking Manager** from the Start menu.

**Portable (no install)**: unzip `BookingManager-Windows-portable.zip` anywhere
(e.g. `Documents\Booking Manager`) and double-click `BookingManager.exe`. Keep
all the files together.

To update, run the newer installer. Your connection and cached data are kept.

## 4. Install on Android (sideload the .apk)

1. On the phone, open the Android link above (or copy `BookingManager.apk`
   over by WhatsApp, Google Drive or a USB cable).
2. Tap the file. Android asks to allow installs from that app (Files, Chrome,
   Drive…). Tap **Settings → Allow from this source**, then go back.
3. Tap **Install**. If Play Protect warns about an unknown app, tap
   **More details → Install anyway**.
4. Open **Booking Manager**, paste the Web App URL and API key, and allow
   notifications so you get the "How much did you get in hand?" reminder after
   each check-out.

### Keep Android updates installable (recommended, one-time)

Android only installs an update over an existing app if both are signed with
the **same key**. Without a key of your own, each build is signed with a
throwaway debug key, and you'd have to uninstall before updating (the app
re-downloads everything from your Sheet, so no data is lost, but it's a
nuisance). To fix it once:

1. On any computer with Java installed, run:
   ```
   keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias booking
   ```
   Choose a password and remember it. Keep `release.jks` safe: it is your
   app's signing key.
2. Convert it to text: `base64 -w0 release.jks` (Mac: `base64 -i release.jks`;
   Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks"))`).
3. In GitHub: **Settings → Secrets and variables → Actions → New repository
   secret**, add:
   - `ANDROID_KEYSTORE_BASE64`: the text from step 2
   - `ANDROID_KEYSTORE_PASSWORD`: your password
   - `ANDROID_KEY_ALIAS`: `booking`
   - `ANDROID_KEY_PASSWORD`: your password

From the next build on, every APK is signed with your key.

## Keeping phone and laptop in sync

Connect both apps to the same Sheet (same Web App URL and API key). Each app
syncs when it opens, when you come back to it, every 2 minutes while it is
open, straight after every edit, and when you pull to refresh or click ↻.
Edits made offline are kept on the device and sent when it is back online.
If the same booking is edited on two devices before either syncs, the last
save wins.

## 5. Try it without setting anything up

On the first screen, tap **Explore with demo data**: a year of made-up
bookings so you can click around. **Settings → Leave demo** returns to the
connect screen.

---

## How the money is worked out

| Figure | Formula |
|---|---|
| Nights | check-out − check-in |
| Platform cut ₹ | guest paid − in hand |
| Platform cut % | cut ÷ guest paid |
| Profit | in hand − costs |
| In hand per night | in hand ÷ nights |
| Occupancy | booked nights ÷ available nights (calendar nights × properties − blocked nights) |
| ADR | in hand ÷ booked nights (nights with an in-hand amount) |
| RevPAN | in hand ÷ available nights |

- Stays that span two periods (e.g. 30 Oct to 2 Nov) are split by night.
- A stay with no in-hand amount yet is never estimated. It shows as
  *pending* and is left out of cut, profit and ADR.
- Cancelled bookings don't count towards money or occupancy. They are counted
  as cancellations, with the nights lost.

## For developers

```
# Backend
cd apps-script && npm install && npm test     # parser, API and pipeline tests
npm run bundle                                 # rebuild dist/BookingApp.gs

# App
cd app && flutter pub get
flutter test                                   # money, insights, Excel export
flutter run -d windows                         # or an Android device
flutter build web && open build/web            # browser preview (demo data)
```

The app is built with Flutter 3.50 (stable).
