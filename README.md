<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/images/branding.png">
    <img src="assets/images/branding_green.png" alt="Wavelog Portable" width="420">
  </picture>
</p>

<p align="center"><b><a href="https://greenlava82.github.io/WavelogPortable/">Website</a></b> · <a href="#setup">Setup</a> · <a href="#development">Development</a></p>

# Wavelog Portable

A fast, field-friendly amateur radio logger for Android (and iPhone), built with Flutter. It logs straight to your own [Wavelog](https://github.com/wavelog/wavelog) server and keeps working when the signal drops, which makes it a good fit for POTA and SOTA activations and for park hunting.

Developed by K1GLV. Powered by (and with thanks to) the Wavelog project. See the [website](https://greenlava82.github.io/WavelogPortable/) for screenshots.

## Features

### Logging

- **Big callsign keypad.** Type the call on the main screen and tap → to open Log Contact.
- **Band and frequency dial.** Swipe the band and VFO dials, or use −/+ for 1 kHz steps. The app remembers the last frequency and mode on each band.
- **Modes.** SSB, CW, FM, AM, DMR, C4FM, D-STAR, FreeDV, FT8, FT4, JS8, RTTY, PSK31 and SSTV. Choose which ones show in Settings → Active Modes. FreeDV is logged the way ADIF expects (`MODE=DIGITALVOICE`, `SUBMODE=FREEDV`).
- **Signal reports.** Defaults to 59 / 599; tap either report to change it.
- **Callsign lookup.** Name, location and grid come from, in order:
  1. QRZ, if you've entered a QRZ login in Settings (full names and licence class).
  2. The callbook set up on your Wavelog server (QRZ, HamQTH, QRZCQ, QRZ.ru or qrzcall.eu), so the phone needs no login of its own. With HamQTH, Wavelog passes on the operator's nickname, which is usually just a first name.
  3. What Wavelog knows from your last contact with the call, and its country.

  Each result is cached on the phone, so a call you've looked up before still fills in offline.
- **Map.** Tap the map icon on Log Contact to see where the other station is. Labels are in English worldwide. See [Map](#map).

### Worked before and contact history

- **NEW / WORKED badge.** Shows whether you've worked the call before, and on this band and mode.
- **Contact history** (API v2 key, online). The badge reads **WORKED 5×**. Tap it for your 5 most recent contacts with that station, with date, band and mode; rows on the same band are bold and same band and mode are blue. Wavelog matches the call exactly, so W1AW/P history isn't included for W1AW.

### POTA and SOTA

- **Offline park and summit search.** Settings → Download POTA/SOTA Databases saves the official lists (about 15 MB) on the phone. Search by reference (`US-1234`, or just `1234`, including 5-digit parks) or by name.
- **Several parks per contact.** Add as many parks as the other station is activating. They're sent to Wavelog as `POTA_REF` / `SOTA_REF`.
- **Recall last parks.** When two operators share a park, tap the history button (🕘) at the top of **Select Activity** to add the parks from the contact you just logged. It's greyed out until you've logged a contact with a park.

### Sessions and offline mode

- **Sessions.** Start a session from the menu to group an activation's contacts. Manage Sessions lets you view, resume, edit or delete them.
- **Offline mode.** Switch it on in the menu and contacts are queued on the phone. **Sync Queue** uploads them to the Station Profile you pick once you're back online.

### Logbook viewer

Tap the book icon on the main screen to see your latest 10, 25, 50 or 100 contacts.

- With an API v2 key and a connection, the list comes from Wavelog (green), so it includes contacts logged elsewhere.
- Otherwise (v1 key or offline) it shows the contacts logged on this phone (orange), and says why.

### Daily streak

A banner under the title bar shows your Wavelog streak, counted the same way as Wavelog's dashboard: consecutive UTC days with at least one contact.

| Banner | Meaning |
|---|---|
| 🔥 **9-day streak · 10 QSOs today** (green) | You've logged today; the streak is safe. |
| 🔥 **No contacts today · 9-day streak ends in 2h 15m** (orange) | No contact yet today. The streak ends at 00:00 UTC. |
| 📻 **No contacts today (UTC) yet** (grey) | No streak running. |

- **Reminder.** At about 21:45 UTC, if you haven't logged anything that day, the phone shows *"Your 9-day streak ends at 00:00 UTC"*, a little over two hours before the day ends. It comes from a background check, so the app doesn't need to be open. On Android the check may run a few minutes late; the notification states the actual time left. On iPhone, the reminder is set while the app is open and the streak is at risk, and cleared once you log.
- **Counts.** Contacts logged on the phone count right away, even offline or still waiting to upload.
- **Turning it off.** Settings → Daily Streak → **Streak tracker** hides the banner and stops the reminder.
- **Needs** an API v2 key (`wl2_…`). With a v1 key the banner and reminder don't appear.

### Map

- **Online:** Esri World Street Map, which labels every country and city in English (OpenStreetMap's standard map switches language and script by region).
- **Offline:** a low-detail world map is built into the app (about 3 MB): coastlines, borders, US/Canadian and some other state or province lines, and major cities, all in English. It shows automatically when there's no signal, down to about state level; closer in, the map goes grey until you're back online.

## Setup

1. **My Station.** Enter your callsign and grid square.
2. **Wavelog Integration.**
   - **Wavelog URL**, e.g. `https://log.mysite.com`.
   - **API key.** Both kinds work, but a **v2 key (`wl2_…`) is recommended**: contact history, the logbook from Wavelog, and the daily streak need it. Create it in Wavelog with the scopes `station:read`, `qso:read`, `qso:write` and `lookup:read`. The app shows which API version and scopes it detected under the key field.
   - **Station Profile.** Tap Refresh and choose the profile to log to.
3. **Callbook.** Set one up on your Wavelog server, in its `config.php`: for example `$config['callbook'] = 'hamqth';` with `hamqth_username` and `hamqth_password` (HamQTH is free and includes grids), or `'qrz'` with a QRZ XML subscription. A list such as `['qrz', 'hamqth']` tries each in turn. The **QRZ Login** in the app's Settings is optional; add one for full names and licence class (it's tried first).
4. **Databases.** Tap **Download POTA/SOTA Databases** once, on Wi-Fi, for offline park and summit search.
5. **Daily Streak.** On by default. Allow notifications when asked to get the evening reminder.

## Branding

The app icon and logo are hand-drawn originals, lightly cleaned up to work as an app icon (Android adaptive icon, splash screen, Play Store). The logo comes in white (`branding.png`, for dark backgrounds) and green (`branding_green.png`, for light ones). The originals and the scripts used are in [`assets/images/source`](assets/images/source); regenerate the icons with:

```bash
dart run flutter_launcher_icons
```

Development builds use the same icon with a **DEV** badge (see below).

## Development

Flutter 3.38 / Dart 3.10. Main packages: `sqflite`, `shared_preferences`, `http`, `flutter_map`, `workmanager`, `flutter_local_notifications`.

```bash
flutter test
```

```bash
flutter analyze
```

### Development build next to the Play Store app

Debug builds install as a separate app, **Wavelog Dev** (`com.k1glv.wavelogportable.dev`, version `x.y.z-dev`, DEV-badged icon). You can keep the Play Store version for real logging and test changes side by side. Each app has its own settings and data, and both run the streak reminder if it's switched on in both.

```bash
flutter run
```

Release builds (`flutter build appbundle`) keep the Play Store ID `com.k1glv.wavelogportable`.

Development builds also add **Settings → Daily Streak → Send test reminder**, which shows the streak notification immediately, with your current streak, to check how it looks.

### Website

The marketing page is [`docs/index.html`](docs/index.html), published by GitHub Pages from the `docs/` folder on `main`. Changes go live about a minute after they're merged.

### Rebuilding the offline map

The bundled map tiles (`assets/map/{z}/{x}_{y}.png`, zoom 0–5) are drawn from public-domain [Natural Earth](https://www.naturalearthdata.com) 1:50m data by [`tool/render_offline_map.py`](tool/render_offline_map.py) (needs Pillow and pyshp). The script lists the six Natural Earth downloads it uses.

```bash
python tool/render_offline_map.py ~/natural-earth assets/map
```

## Ideas and to-do

See [TODO.md](TODO.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
