# Nekodoku — Deliverable Findings

Everything found in this repo about the shipped builds and assets, dated from the 8 September 2026 delivery pass (`.godot-vibe/delivery-20260908/`).

## 1. What the game is

- **Project name:** Nekodoku (repo folder `catsweeper`). Godot 4.7, Forward+ renderer, Jolt Physics, d3d12 on Windows.
- **Gameplay:** "Catsweeper" — a logic puzzle. Place one cat per row, per column, and per colored territory on an N×N grid; no two cats may touch (adjacent or diagonal) and no two may share a region. Boards are 5×5, 6×6, and 7×7.
- **Code:** one scene (`scenes/main.tscn`) driving one script (`scripts/catsweeper.gd`, ~1300 lines, all logic + all drawing) plus `scripts/puzzles.gd` (15 handmade boards + an endless procedural generator) and `shaders/twilight.gdshader` (animated background).
- **Localization:** 4 languages — English, French, Brazilian Portuguese, Spanish. 43 messages in `assets/i18n/ui.csv`, compiled to `.translation` files. Language pill cycles EN / FR / PT / ES.
- **Save:** `user://catsweeper.cfg` stores `unlocked_level` and `language`.
- **Tests:** `tests/run_tests.gd` (SceneTree runner, 390 lines). Delivery checks counted 9 scripts passing the import/syntax gate and a green test run.
- **Feel values:** speed, damping, durations, and thresholds are all `@export` vars in `catsweeper.gd` (Feel / Style / Atmosphere / Audio groups), tuneable in the Inspector.

## 2. Export presets (`export_presets.cfg`)

- **Android** — Gradle build, min SDK 24 (Android 7.0), `arm64-v8a` only, version code `9`, version name `1.0.8`, package `com.strobetano.catsweeper`, display name "Nekodoku".
- **Web** — single-threaded, no GDExtension, no thread support, canvas resize policy 2, PWA disabled, custom HTML shell empty.

## 3. The three build artifacts

| Artifact | File | Size |
|---|---|---|
| Native Android APK | `Nekodoku-Android-v1.0.8-build9-arm64-release.apk` | 28,919,621 bytes |
| Web build (zip) | `Nekodoku-Web-v1.0.8-build9.zip` | 11,948,648 bytes |
| **WebView APK** (web wrapped in an APK) | `Nekodoku-WebView-Android-v1.0.8-build9.apk` | 12,383,337 bytes |

### Native Android APK
- Gradle output at `android/build/build/outputs/apk/standard/release/android_release.apk`.
- Native libs are **not DLLs** — Godot on Android uses `.so`: `libgodot_android.so` + `libc++_shared.so` per ABI (arm64-v8a / armeabi-v7a / x86 / x86_64). Only arm64-v8a ships.
- Engine libs still account for ~24.48 MB compressed; total was cut 23.77% (37,936,040 → 28,919,621 bytes) by:
  - 11 texture imports → Lossy at existing 0.7 quality (dimensions/transparency preserved),
  - 4 audio cues → mono 22.05 kHz Vorbis q0 (38,742 → 17,069 bytes source),
  - excluding test/editor bridge scripts and the mascot PNG.
- Signing cert SHA-256: `CD09E5BCB70DC0A60751602F168E2AB3B45AD8665101510DB318329DF3C05967`.
- APK SHA-256: `E77104B558AE5803DD63BD33B87F3B6904C9AEC6DA275A2BF3FE35E7E63EB7AF`.

### Web build
- Godot 4.7.2, Emscripten 4.0.20, **single-threaded, no GDExtension**, WebGL 2.0.
- 9 files: `index.html`, `index.js`, `index.wasm` (39.5 MB), `index.pck` (1.47 MB), `index.icon.png`, `index.apple-touch-icon.png`, `index.png`, `index.audio.worklet.js`, `index.audio.position.worklet.js`.
- Hosting needs HTTPS, `.wasm` → `application/wasm`, `.pck` → `application/octet-stream`, no COOP/COEP headers required (single-threaded).
- ZIP SHA-256: `CB4D5FF4373943D9BFCB86D37A60AB63362016C76FB4FB1A4A7DDB17C70B5433`.

### WebView APK — "APK that wraps the web build"
- A thin Android app that hosts the **exact exported web build** in the system WebView. This is the likely test vehicle for a Google Pixel.
- Package `com.strobetano.nekodoku.web` (distinct from the native `com.strobetano.catsweeper`), label "Nekodoku", portrait, fullscreen, `INTERNET` permission, `usesCleartextTraffic` for the loopback server.
- `MainActivity.java` spins up a **loopback HTTP server on `127.0.0.1` (ephemeral port)** and serves `assets/web/*`, so WebView can fetch the `.wasm`/`.pck` over HTTP just like a real web server (supports Range requests, correct MIME types).
- Contains `assets/web/index.html`, `index.wasm` (39.5 MB), `index.pck` (1,468,108 bytes).
- Built by `build_webview_apk.py`: `aapt2` (compile+link) → `javac --release 11` → `d8` → `zipalign -p 4` → `apksigner`, signed with the **same release keystore** (`nekodoku-release.keystore`, alias `nekodoku`) as the native APK, so it can upgrade/replace it.
- Native APK kept beside it for comparison: `previous-native-apk/Nekodoku-Android-v1.0.8-build9-arm64-release.apk`.

## 4. APK provider-authority bug (why `tmp/check_apk.py` exists)

- `tmp/check_apk.py` decodes an APK's **binary `AndroidManifest.xml`** and lists every `<provider>` `authorities=` value.
- It exists because Godot's **non-Gradle Android export** produced APKs with two providers sharing the same authority, making them **uninstallable**. The script exits non-zero on a duplicate authority.

## 5. App Store / marketing assets

Delivered to `C:\Users\rober\Desktop\Nekodoku_App_Store_Package\`:

- **01_App_Store_Assets** — 38 localized screenshots (English + French), 5 scenes each (01_Hero, 02_Rules, 03_Hints, 04_Challenges, 05_Celebration):
  - `Android_Phone_1080x1920` → 1080×1920
  - `iPhone_6.9-inch` → 1320×2868
  - `iPad_13-inch` → 2064×2752
- **Marketing art** (per language): Google Play Feature 1024×500, Apple Product Page Header 3840×1646, Apple Search Results 3840×2560, Apple Universal Cover 5244×2950.
- **Shared masters:** muted watercolor hero `Nekodoku_Hero_Master.png` (1536×1024) and `Nekodoku_Portrait_Master.png` (1024×1536), generated from the existing cat mascot via the built-in `image_gen` tool. App icon at 1024 and 512.
- **02_Build** — the native APK + Web zip (+ unpacked `Web/`).
- **03_Submission_Notes** — `ASSET_MANIFEST.txt`, `ART_PRODUCTION.txt`, `WEB_README.txt`.

## 6. Verification status (from the delivery notes)

- Godot import/syntax gate: **PASS** (9 scripts).
- Gameplay + language test runner: **PASS** (exit 0). Spanish covered 43 messages, layout fit, `es_ES`/`es_MX` mapping, full language cycling, saved-language restore.
- Android: export completed; APK signature, ZIP integrity, language resources, package version, and unique provider authorities verified. Exported resources loaded cleanly in desktop Godot.
- Web: Chromium 147 (Windows) — clean startup in all four locales, mouse/touch tutorial, room unlock, audio sample starts, save restore after reload. No browser warnings/JS errors/failed requests.
- Marketing: all 38 PNGs passed integrity/dimension/placement/proportion checks; zero overlaps; ten original gameplay captures unchanged.
- **Not tested:** no Android device/emulator install test, and Orange hosting + physical mobile browsers were out of scope.

## 7. Note on "DLL"

No `.dll` files exist anywhere in this project. It's a Godot project, so native code ships as **`.so`** on Android and **`.wasm`** on Web. There is no C#/.NET assembly either — the export presets use GDScript (`script_export_mode=2`).
