# Changelog

## 1.1.0 (build 6)

### New
- **API v2 keys.** Wavelog `wl2_` keys work alongside v1 keys; the key field shows which version and scopes were detected.
- **Contact history.** The WORKED badge shows how many times you've worked the call ("WORKED 5×"); tap it for your 5 most recent contacts with that station (v2 key).
- **Logbook viewer.** The book icon shows your last 10–100 contacts, from Wavelog (v2 key) or from the phone.
- **Daily streak.** A banner shows your Wavelog QSO streak and today's count, and a reminder at 21:45 UTC warns on days you haven't logged yet. The banner shows whenever you use a v2 key; the reminder can be switched off in Settings.
- **Recall last parks.** A button in Select Activity adds the parks from the contact you just logged, for when two operators share a park.
- **FreeDV** is now a loggable mode (sent to Wavelog as DIGITALVOICE / FREEDV).
- **Lookups through Wavelog.** If the phone has no QRZ login, or QRZ doesn't know the call, names and locations come from the callbook set up on your Wavelog server, then from your last contact with the call.
- **Better map.** Labels are in English everywhere, and a built-in world map keeps the map working without a signal.

### Improved
- Park search accepts 5-digit references and is more forgiving; Settings shows when the park list was downloaded.
- Polished app icon (same hand-drawn artwork).

### Fixed
- Looking up a call QRZ doesn't know no longer retries forever in the background.
- The sync spinner in the menu no longer gets stuck.
- The location line no longer starts with a stray comma when the city is unknown.

### Play Store "What's new" (under 500 characters)

```
New in 1.1:
• Daily QSO streak banner, with an evening reminder before it ends
• Tap WORKED to see your past contacts with a station (API v2 key)
• Logbook viewer for your latest contacts
• Recall the last parks with one tap when hunting two-op activations
• FreeDV mode
• Callsign lookups through your Wavelog server's callbook
• English map labels, and a built-in map that works offline
• Fixes for QRZ lookups and the sync spinner
```

## 1.0.2 (build 5)

Earlier releases: see the git tags `v1.0.0+2`, `v1.0.1+4` and `v1.0.2+5`.
