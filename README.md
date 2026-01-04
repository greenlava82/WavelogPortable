# K1GLV Logger

**A lightweight, mobile-first amateur radio logging application built with Flutter.**

This project is designed for ham radio operators who need a fast, streamlined way to log contacts (QSOs) in the field—whether you are doing POTA (Parks on the Air), SOTA (Summits on the Air), or just operating casually from the couch.

## 🚀 The Problem
The Wavelog/Cloudlog web based functionality is great, but the web based interface does not scale well.  Other phone based logging apps exist, but few will upload directly to Wavelog. This app serves to bridge that gap 

## ✨ Key Features

* **Hybrid Callsign Lookup:**
    * Automatically queries **Callook.info** for US callsigns (fast, free, detailed license class data).
    * Seamlessly falls back to **QRZ XML** (or HamQTH) for international contacts.
* **Smart Frequency Control:**
    * A virtual "Radio Dial" for fine-tuning frequency.
    * **Direct Entry Keypad:** Intelligently handles MHz vs. kHz input (e.g., typing "14200" or "14.2" both tune to 14.200 MHz).
    * Band-aware limits to keep you inside the amateur bands.
* **Persistent State:** The app remembers your last used Band, Mode, and Frequency. If you are running a pileup on 20m SSB, you don't have to re-select those settings for every contact.
* **Live UTC Clock:**
    * Displays real-time UTC (the standard for logging).
    * **Manual Mode:** Tap the clock to freeze time and backdate logs (useful for transcribing paper notes).
* **Clean UI:** Critical controls (RST, Mode) are tucked away in pop-ups to prevent accidental changes while operating.

## 🛠️ Setup & Installation

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) installed on your machine.
* An Android device or Emulator (iOS is supported by Flutter but untested).
* A **QRZ XML Subscription** (recommended) or HamQTH account for international data lookups.

### Installation
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/YOUR_USERNAME/ham-logger.git](https://github.com/YOUR_USERNAME/ham-logger.git)
    cd ham-logger
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    flutter run
    ```

## ⚙️ Configuration

Before you start logging, you must configure the app. Tap the **Settings (Gear Icon)** on the main screen.

1.  **My Station:** Enter your own callsign and Grid Square.
2.  **Active Modes:** Select the modes you use (SSB, CW, FT8, etc.). Only selected modes will appear in the picker to keep the list clean.
3.  **Wavelog Integration:** Enter your Wavelog/Cloudlog API URL, API Key, and choose a **Station ID** from the Dropdown.
4.  **Lookup Credentials:**
    * Enter your **QRZ** (or HamQTH) Username and Password.
    * *Note: US lookups via Callook do not require a login.*

## 📱 Workflow

1.  **Input:** Open the app and type a callsign (e.g., `W1AW`).
2.  **Lookup:** Hit **Enter**. The app fetches the operator's Name, Location, and Grid Square automatically.
3.  **Details:** You are taken to the **Contact Details** screen.
    * **Time:** Auto-filled with current UTC.
    * **Band/Freq:** Auto-filled from your previous contact.
    * **RST:** Defaults to 59/599. Tap to adjust.
4.  **Log It:** Tap the **Save** icon.
    * The contact is logged (printed to console/local storage).
    * You are returned to the input screen.
    * The callsign field is automatically cleared, ready for the next one.

## 🚧 Project Status

* [x] **UI/UX:** Fully functional Material 3 design.
* [x] **Lookup Engine:** Hybrid Callook + QRZ XML implemented.
* [x] **State Management:** Persistence for radio settings.
* [ ] **POTA/SOTA/Comments:** fill out additional fields in your Wavelog QSO log is currently in development
* [x] **Wavelog Upload:** API integration is currently in development.
* [ ] **Local Database:** SQLite storage for offline history is planned.

## 🚀 Roadmap / Todo

### Next Session
* [x] **Settings:** Implement "Fetch Station ID" button to populate a dropdown menu from Wavelog API.
* [ ] **Details UI:** Add input fields for **POTA Ref**, **SOTA Ref**, and **Comments**.
* [ ] **ADIF Export:** Update WavelogService to include the new POTA/SOTA/Comment tags in the upload.
* [x] **QSO History:** Query Wavelog for previous contacts with the current callsign and display a "History" indicator/list.

### Future
* [ ] **Local Database:** SQLite storage for offline history.
* [ ] **Branding:** Custom App Icon and Splash Screen.

## 📄 License

This project is open source. Feel free to fork and modify it for your own shack!
