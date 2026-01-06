# K1GLV Wavelog Mobile

A specialized, offline-first amateur radio logging application built with Flutter. Designed to interface directly with a self-hosted [Wavelog](https://github.com/wavelog/wavelog) instance via API.

## 🚀 Current Features

### 📡 Logging & Wavelog Integration
* **Direct API Upload:** Logs contacts immediately to Wavelog in ADIF format.
* **Dupe Checking:** Checks `private_lookup` endpoint on Wavelog to show "WORKED" (Band/Mode specific) or "NEW" badges in real-time.
* **Station Profiles:** Dynamically fetches and allows selection of Station Profile IDs from the server.
* **Offline Queueing:** (Partial) UI state is saved locally between sessions.

###  Parks & Summits (POTA / SOTA)
* **Offline Database:** Downloads official POTA (`all_parks.csv`) and SOTA (`summitslist.csv`) databases (~15MB) to local SQLite storage.
* **Instant Search:** Search for parks or summits by Reference ID (e.g., `K-1234`) or Name (e.g., `Greylock`) without internet access.
* **ADIF Compliance:** correctly maps selections to `POTA_REF` and `SOTA_REF` tags for Wavelog ingestion.

### 🗺️ Mapping & Location
* **Grid Square Visualization:** Converts 4 or 6-character Maidenhead grid squares to Lat/Lon.
* **Offline Maps:** Uses `flutter_map` with OpenStreetMap tiles to visualize contact locations.
* **Callsign Lookup:** Hybrid lookup strategy using **Callook.info** (US/Free) and **QRZ XML** (International/Backup).

### 🎛️ Radio Control UI
* **Virtual VFO:** Custom "Radio Dial" widget for frequency selection with 1kHz stepping.
* **Smart Mode:** Remembers the last used frequency/mode per band.
* **RST Sliders:** Rapid entry for Signal Reports (59 / 599).

## 🛠️ Technical Stack
* **Framework:** Flutter (Dart)
* **Storage:** `shared_preferences` (Settings), `sqflite` (POTA/SOTA DB).
* **Networking:** `http` (Wavelog API, QRZ, POTA Downloads).
* **Mapping:** `flutter_map`, `latlong2`.

## 📋 Todo / Roadmap

* [ ] **Live Spot Integration:** Query POTA/SOTA "Active Spots" APIs to auto-fill park references based on the entered callsign.
* [ ] **Offline Logging Queue:** Store logs locally if the Wavelog server is unreachable and sync when online.
* [ ] **WWFF Support:** Add support for World Wide Flora & Fauna databases.
* [ ] **UI Refinement:** Tablet/Landscape layout optimizations.

## 🔑 Setup
1.  **Settings:** Enter your Wavelog Base URL (e.g., `https://log.mysite.com/index.php/api`) and API Key.
2.  **Credentials:** Enter QRZ/HamQTH credentials for international lookups.
3.  **Databases:** Go to Settings and tap "Download POTA/SOTA Databases" to initialize the offline search.