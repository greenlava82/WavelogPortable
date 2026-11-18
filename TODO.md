# TODO

## Features

### Using the Wavelog API v2 calls the app already makes

- [ ] **Contact history while typing a call.** Replace the yes/no worked-before answer with the station's past contacts (date, band, mode), e.g. "Worked 3×: 2026-10-02 20m FT8, …".
  - First check whether `GET /api/v2/qso` can filter by callsign; so far the app only uses `limit`.
- [ ] **Activation check after a session.** Compare the session's contacts on the phone with what's in Wavelog and flag any that are missing (POTA/SOTA field uploads can drop out).
- [ ] **Safer retries.** Before re-sending a queued contact, check whether Wavelog already has it, so an upload that timed out but succeeded doesn't become a duplicate.

### Needing parts of v2 the app doesn't use yet

- [ ] **Edit or delete a contact from the logbook viewer.** Tap a row to fix the band or a typo in the call, or delete the contact.
  - Depends on v2 supporting edits and deletes; check first.
- [ ] **Station profile per activation.** Choose the right station profile when starting a POTA/SOTA session, or create one for a new location.
  - Creating one depends on v2 allowing it.

### Portable operating (not Wavelog-related)

- [ ] **POTA progress meter.** "7 / 10 for a valid activation", plus counts per band and mode for the session. Works offline.
- [ ] **Hunt from POTA spots.** A list of live spots from pota.app; tapping one fills in call, frequency, mode and park.
- [ ] **Park-to-park.** Log your own park alongside theirs. The app already sends the other station's park as `POTA_REF`.

## Housekeeping

- [ ] Log one real contact with the v2 key and confirm it appears in Wavelog (v2 upload is only covered by unit tests).
- [ ] Bump the app version (still 1.0.2+5).
- [ ] Rebase or retire the local-only `drt/offlinedb` branch.
- [ ] Remove `android/build/reports/problems/problems-report.html`, which was committed by accident.
- [ ] Map other digital submodes to ADIF properly (FT4, JS8, PSK31, DMR, C4FM, D-STAR), as was done for FreeDV.
- [ ] Delete merged remote branches.
- [ ] Check the new icon on iOS and web.
