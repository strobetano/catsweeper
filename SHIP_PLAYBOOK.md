# Ship a Godot Game to Android (Pixel) — Reusable Playbook

A generic, copy-paste recipe to take any Godot game, produce the three shippable artifacts (native APK, web build, and a small "web-wrapped" APK), and generate store-ready marketing assets. Built from the Nekodoku/catsweeper delivery. Replace every `⟨PLACEHOLDER⟩` with the other game's values.

## 0. Prerequisites (one-time toolchain)

- Godot 4.7 (or 4.x) with **official export templates** for Android and Web.
- JDK 21 (e.g. Eclipse Adoptium). `JAVA_HOME` must point to it.
- Android SDK with: `build-tools/36.1.0` (gives `aapt2`, `d8`, `zipalign`, `apksigner`) and `platforms/android-36/android.jar`.
- A release keystore, e.g. `⟨GAME⟩-release.keystore` with a single alias and its password in a sidecar file.

Paths used below (mirror Nekodoku's layout):

```
SDK        = C:\Android\android-sdk
BUILD_TOOLS= $SDK\build-tools\36.1.0
ANDROID_JAR= $SDK\platforms\android-36\android.jar
JDK        = C:\Program Files\Eclipse Adoptium\jdk-21.0.9.10-hotspot
KEYSTORE   = %APPDATA%\Godot\keystores\⟨GAME⟩-release.keystore
KEY_PASS   = %APPDATA%\Godot\keystores\⟨GAME⟩-release.password.txt
KEY_ALIAS  = ⟨GAME⟩
```

## 1. Export presets (`export_presets.cfg`)

Set these, then export from the Godot editor or headless.

**Android preset**
```
platform="Android"
gradle_build/use_gradle_build=true
gradle_build/min_sdk="24"              # Android 7.0
architectures/arm64-v8a=true           # ship arm64 only
architectures/armeabi-v7a=false
architectures/x86=false
architectures/x86_64=false
version/code=1
version/name="1.0.0"
package/unique_name="com.⟨studio⟩.⟨game⟩"
package/name="⟨Game⟩"
export_filter="all_resources"
exclude_filter="tests/*, addons/<editor bridges>"
script_export_mode=2                   # GDScript, no .NET
```

**Web preset** (single-threaded is what makes the wrapper simple — no COOP/COEP):
```
platform="Web"
variant/extensions_support=false
variant/thread_support=false
html/canvas_resize_policy=2
progressive_web_app/enabled=false
```

## 2. The three artifacts

| # | Artifact | How | Purpose |
|---|---|---|---|
| A | Native APK | Godot Android export (Gradle) | Play Store / normal install |
| B | Web build | Godot Web export | host anywhere (Orange, itch, etc.) |
| C | **WebView APK** | wrap (B) in a tiny Android app | small installable APK for Pixel sideload testing |

## 3. WebView APK — the "wrap the web build in an APK" trick

Why: the native Godot APK carries ~24 MB of engine `.so`; the web-wrapped APK is a thin shell (~12 MB compressed) hosting the already-built web files. Ideal for side-loading onto a Pixel.

### 3.1 Layout

```
webview-apk/
  AndroidManifest.xml
  res/drawable/ic_launcher.png        # copy the 512px app icon
  assets/web/                         # the exact Godot web export, unpacked
    index.html  index.js  index.wasm  index.pck  *.png  *.worklet.js
  src/com/⟨studio⟩/⟨game⟩/web/MainActivity.java
  build_webview_apk.py
```

### 3.2 `AndroidManifest.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.⟨studio⟩.⟨game⟩.web">
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36" />
    <application
        android:label="⟨Game⟩"
        android:icon="@drawable/ic_launcher"
        android:hardwareAccelerated="true"
        android:usesCleartextTraffic="true"
        android:theme="@android:style/Theme.Black.NoTitleBar.Fullscreen">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:screenOrientation="portrait"
            android:configChanges="orientation|screenSize|keyboardHidden|screenLayout|smallestScreenSize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 3.3 `MainActivity.java`

The key idea: a WebView can't `file://`-load a `.wasm`/`.pck` reliably, so run a **loopback HTTP server on `127.0.0.1`** that serves `assets/web/*`, then point the WebView at `http://127.0.0.1:PORT/index.html`. This file is already generic — only the `package` line and `ASSET_ROOT` matter.

```java
package com.⟨studio⟩.⟨game⟩.web;

import android.app.Activity;
import android.content.res.AssetManager;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;

import java.io.BufferedOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.InetAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.net.URLDecoder;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public class MainActivity extends Activity {
    private static final String ASSET_ROOT = "web";

    private final Map<String, String> mimeTypes = new HashMap<String, String>();
    private volatile boolean running = false;
    private ServerSocket serverSocket;
    private WebView webView;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);

        mimeTypes.put("html", "text/html");
        mimeTypes.put("js", "text/javascript");
        mimeTypes.put("wasm", "application/wasm");
        mimeTypes.put("pck", "application/octet-stream");
        mimeTypes.put("png", "image/png");
        mimeTypes.put("json", "application/json");
        mimeTypes.put("css", "text/css");
        mimeTypes.put("svg", "image/svg+xml");

        webView = new WebView(this);
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        webView.setBackgroundColor(Color.BLACK);
        webView.setWebViewClient(new WebViewClient());

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(Color.BLACK);
        root.addView(webView, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);
        hideSystemUi();

        int port;
        try {
            serverSocket = new ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"));
            port = serverSocket.getLocalPort();
        } catch (IOException error) {
            webView.loadData("⟨Game⟩ could not start its local player.", "text/plain", "utf-8");
            return;
        }
        running = true;
        Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                serve();
            }
        }, "⟨game⟩-assets");
        thread.setDaemon(true);
        thread.start();
        webView.loadUrl("http://127.0.0.1:" + port + "/index.html");
    }

    private void hideSystemUi() {
        getWindow().getDecorView().setSystemUiVisibility(
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | View.SYSTEM_UI_FLAG_FULLSCREEN
                        | View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY);
    }

    @Override protected void onPause()  { super.onPause();  if (webView != null) webView.onPause(); }
    @Override protected void onResume() { super.onResume(); if (webView != null) webView.onResume(); }

    @Override
    protected void onDestroy() {
        running = false;
        if (serverSocket != null) { try { serverSocket.close(); } catch (IOException ignored) {} }
        if (webView != null) webView.destroy();
        super.onDestroy();
    }

    private void serve() {
        while (running) {
            Socket socket;
            try { socket = serverSocket.accept(); }
            catch (IOException error) { if (!running) break; continue; }
            handle(socket);
        }
    }

    private void handle(Socket socket) {
        try {
            socket.setSoTimeout(15000);
            InputStream in = socket.getInputStream();
            String requestLine = readLine(in);
            if (requestLine == null) { socket.close(); return; }
            String[] parts = requestLine.split(" ");
            String method = parts.length > 0 ? parts[0] : "GET";
            String rawPath = parts.length > 1 ? parts[1] : "/";
            long rangeStart = -1, rangeEnd = -1;
            String header;
            while ((header = readLine(in)) != null && header.length() > 0) {
                if (header.toLowerCase(Locale.US).startsWith("range:")) {
                    int equals = header.indexOf('=');
                    String value = equals >= 0 ? header.substring(equals + 1).trim() : "";
                    if (value.startsWith("bytes=")) value = value.substring(6);
                    int dash = value.indexOf('-');
                    if (dash >= 0) {
                        String first = value.substring(0, dash).trim();
                        String second = value.substring(dash + 1).trim();
                        try { rangeStart = first.isEmpty() ? -1 : Long.parseLong(first); } catch (NumberFormatException e) { rangeStart = -1; }
                        try { rangeEnd = second.isEmpty() ? -1 : Long.parseLong(second); } catch (NumberFormatException e) { rangeEnd = -1; }
                    }
                }
            }

            String path = rawPath;
            int query = path.indexOf('?');
            if (query >= 0) path = path.substring(0, query);
            path = URLDecoder.decode(path, "UTF-8");
            if (path.isEmpty() || path.equals("/")) path = "/index.html";
            if (path.startsWith("/")) path = path.substring(1);
            if (path.contains("..")) { sendError(socket, 403, "Forbidden"); return; }

            InputStream asset;
            try { asset = getAssets().open(ASSET_ROOT + "/" + path); }
            catch (IOException missing) { sendError(socket, 404, "Not found"); return; }

            int total = asset.available();
            boolean partial = rangeStart >= 0;
            long start = partial ? rangeStart : 0;
            long end = partial ? (rangeEnd >= 0 ? Math.min(rangeEnd, (long) total - 1) : (long) total - 1) : (long) total - 1;
            if (partial && start > end) { asset.close(); sendError(socket, 416, "Range not satisfiable"); return; }
            long skipped = 0;
            while (skipped < start) { long step = asset.skip(start - skipped); if (step <= 0) break; skipped += step; }
            long length = end - start + 1;

            OutputStream out = new BufferedOutputStream(socket.getOutputStream(), 64 * 1024);
            StringBuilder headers = new StringBuilder();
            headers.append("HTTP/1.1 ").append(partial ? "206 Partial Content" : "200 OK").append("\r\n");
            headers.append("Content-Type: ").append(guessMime(path)).append("\r\n");
            headers.append("Content-Length: ").append(length).append("\r\n");
            headers.append("Accept-Ranges: bytes\r\n");
            headers.append("Cache-Control: no-store\r\n");
            if (partial) headers.append("Content-Range: bytes ").append(start).append('-').append(end).append('/').append(total).append("\r\n");
            headers.append("Connection: close\r\n\r\n");
            out.write(headers.toString().getBytes("US-ASCII"));
            if (!method.equals("HEAD")) {
                byte[] buffer = new byte[64 * 1024];
                long remaining = length;
                while (remaining > 0) {
                    int read = asset.read(buffer, 0, (int) Math.min(buffer.length, remaining));
                    if (read < 0) break;
                    out.write(buffer, 0, read);
                    remaining -= read;
                }
            }
            out.flush(); asset.close(); socket.close();
        } catch (IOException error) {
            try { socket.close(); } catch (IOException ignored) {}
        }
    }

    private String readLine(InputStream in) throws IOException {
        StringBuilder line = new StringBuilder();
        int current;
        while ((current = in.read()) != -1) {
            if (current == '\n') return line.toString();
            if (current != '\r') line.append((char) current);
        }
        return line.length() == 0 ? null : line.toString();
    }

    private String guessMime(String path) {
        int dot = path.lastIndexOf('.');
        if (dot >= 0) {
            String mime = mimeTypes.get(path.substring(dot + 1).toLowerCase(Locale.US));
            if (mime != null) return mime;
        }
        return "application/octet-stream";
    }

    private void sendError(Socket socket, int status, String message) {
        try {
            byte[] body = message.getBytes("UTF-8");
            OutputStream out = socket.getOutputStream();
            String headers = "HTTP/1.1 " + status + " " + message + "\r\n"
                    + "Content-Type: text/plain\r\n"
                    + "Content-Length: " + body.length + "\r\n"
                    + "Connection: close\r\n\r\n";
            out.write(headers.getBytes("US-ASCII"));
            out.write(body); out.flush();
        } catch (IOException ignored) {}
        try { socket.close(); } catch (IOException ignored) {}
    }
}
```

### 3.4 `build_webview_apk.py`

Build pipeline: `aapt2 compile` + `aapt2 link` → `javac --release 11` → `d8` → append `classes.dex` → `zipalign -p 4` → `apksigner` with the **same release keystore as the native APK** (so one can upgrade the other). Set the paths at the top.

```python
import hashlib, os, shutil, subprocess, sys, zipfile
from pathlib import Path

ROOT = Path(r"C:\path\to\webview-apk")
WEB  = Path(r"C:\path\to\godot-web-export")          # the unpacked Godot web build
SDK  = Path(r"C:\Android\android-sdk")
BUILD_TOOLS = SDK / "build-tools" / "36.1.0"
ANDROID_JAR = SDK / "platforms" / "android-36" / "android.jar"
JDK   = Path(r"C:\Program Files\Eclipse Adoptium\jdk-21.0.9.10-hotspot")
KEYSTORE = Path(r"C:\Users\YOU\AppData\Roaming\Godot\keystores\⟨GAME⟩-release.keystore")
KEY_PASS = Path(r"C:\Users\YOU\AppData\Roaming\Godot\keystores\⟨GAME⟩-release.password.txt")
ICON  = Path(r"C:\path\to\icon\⟨game⟩_app_icon.png")
OUT_NAME = "⟨Game⟩-WebView-Android-v1.0.0-build1.apk"

BUILD = ROOT / "build"
if BUILD.exists(): shutil.rmtree(BUILD)
(BUILD / "gen").mkdir(parents=True); (BUILD / "classes").mkdir(parents=True); (BUILD / "dex").mkdir(parents=True)

env = dict(os.environ)
env["JAVA_HOME"] = str(JDK)
env["PATH"] = str(JDK / "bin") + os.pathsep + str(BUILD_TOOLS) + os.pathsep + env["PATH"]

def run(args, **kw):
    print(">", " ".join(str(a) for a in args))
    subprocess.run([str(a) for a in args], check=True, env=env, **kw)

assets_web = ROOT / "assets" / "web"
if assets_web.exists(): shutil.rmtree(assets_web)
assets_web.mkdir(parents=True)
for source in sorted(WEB.iterdir()):
    if source.is_file(): shutil.copy2(source, assets_web / source.name)

shutil.copy2(ICON, ROOT / "res" / "drawable" / "ic_launcher.png")

run([BUILD_TOOLS / "aapt2.exe", "compile", "--dir", ROOT / "res", "-o", BUILD / "res.zip"])
run([BUILD_TOOLS / "aapt2.exe", "link", "-o", BUILD / "base.apk", "-I", ANDROID_JAR,
     "--manifest", ROOT / "AndroidManifest.xml", "-A", ROOT / "assets", "-R", BUILD / "res.zip",
     "--java", BUILD / "gen", "--min-sdk-version", "24", "--target-sdk-version", "36",
     "--version-code", "1", "--version-name", "1.0.0"])

java_sources = sorted((ROOT / "src").rglob("*.java"))
run([JDK / "bin" / "javac.exe", "--release", "11", "-classpath", ANDROID_JAR,
     "-d", BUILD / "classes"] + java_sources)

class_files = sorted((BUILD / "classes").rglob("*.class"))
run([BUILD_TOOLS / "d8.bat", "--min-api", "24", "--lib", ANDROID_JAR,
     "--output", BUILD / "dex"] + class_files)

with zipfile.ZipFile(BUILD / "base.apk", "a", zipfile.ZIP_DEFLATED) as apk:
    apk.write(BUILD / "dex" / "classes.dex", "classes.dex")

run([BUILD_TOOLS / "zipalign.exe", "-f", "-p", "4", BUILD / "base.apk", BUILD / "aligned.apk"])
run([BUILD_TOOLS / "apksigner.bat", "sign", "--ks", KEYSTORE, "--ks-pass", "file:" + str(KEY_PASS),
     "--ks-key-alias", "⟨GAME⟩", "--out", BUILD / OUT_NAME, BUILD / "aligned.apk"])
run([BUILD_TOOLS / "apksigner.bat", "verify", "--print-certs", BUILD / OUT_NAME])
run([BUILD_TOOLS / "zipalign.exe", "-c", "-v", "4", BUILD / OUT_NAME])

final = BUILD / OUT_NAME
with zipfile.ZipFile(final) as apk:
    names = apk.namelist()
    assert "classes.dex" in names and "assets/web/index.html" in names
print("APK:", final, "bytes:", final.stat().st_size, "sha256:", hashlib.sha256(final.read_bytes()).hexdigest().upper())
```

## 4. APK size reduction (optional, ~24% saved)

Apply before the native export:

1. Textures → **Lossy** import mode, keep existing quality (0.7), preserve dimensions + transparency.
2. Audio → **mono, 22.05 kHz, Vorbis quality 0**.
3. `exclude_filter` in the Android preset: drop `tests/*`, editor bridge scripts, and any oversized source art (e.g. the mascot PNG).
4. Ship **arm64-v8a only** (skip the other three ABIs). The engine `.so` stays the dominant cost (~24 MB compressed).

## 5. Duplicate-provider authority guard (`check_apk.py`)

Godot's **non-Gradle** Android export could emit two `<provider>` entries with the same `authorities=`, producing an **uninstallable APK**. Run this on every APK before shipping; it exits non-zero on a clash.

```python
import struct, sys, zipfile
data = zipfile.ZipFile(sys.argv[1]).read('AndroidManifest.xml')

def u16(o): return struct.unpack_from('<H', data, o)[0]
def u32(o): return struct.unpack_from('<I', data, o)[0]

off = 8; strings = []; chunks = []
while off < len(data):
    ctype, hsize, csize = u16(off), u16(off + 2), u32(off + 4)
    if csize == 0: break
    chunks.append((ctype, off, hsize))
    if ctype == 0x0001:
        count, flags, sstart = u32(off + 8), u32(off + 16), u32(off + 20)
        utf8 = bool(flags & (1 << 8))
        for i in range(count):
            p = off + sstart + u32(off + hsize + 4 * i)
            if utf8:
                p += 2 if data[p] & 0x80 else 1
                n = data[p]
                if n & 0x80: n, p = ((n & 0x7F) << 8) | data[p + 1], p + 2
                else: p += 1
                strings.append(data[p:p + n].decode('utf-8', 'replace'))
            else:
                n = u16(p)
                if n & 0x8000: n, p = ((n & 0x7FFF) << 16) | u16(p + 2), p + 4
                else: p += 2
                strings.append(data[p:p + n * 2].decode('utf-16-le', 'replace'))
    off += csize

def name(i): return strings[i] if 0 <= i < len(strings) else '#%d' % i

def element(off, hsize):
    p = off + hsize; attrs = {}
    astart, asize, acount = u16(p + 8), u16(p + 10), u16(p + 12)
    for i in range(acount):
        a = p + astart + i * asize
        raw = u32(a + 16)
        attrs[name(u32(a + 4))] = name(raw) if data[a + 15] == 0x03 else raw
    return name(u32(p + 4)), attrs

providers = []
for ctype, off, hsize in chunks:
    if ctype != 0x0102: continue
    tag, attrs = element(off, hsize)
    if tag == 'provider': providers.append(attrs)

seen = {}; clash = False
for a in providers:
    auth = a.get('authorities', '?')
    print('%-45s %s' % (a.get('name', '?'), auth))
    if auth in seen: clash = True
    seen[auth] = a.get('name')
print('\nDUPLICATE AUTHORITY' if clash else '\nOK: all provider authorities unique')
sys.exit(1 if clash else 0)
```

## 6. Store / marketing asset dimensions

Generate per language. Screenshot scenes: `01_Hero, 02_Rules, 03_Hints, 04_Challenges, 05_Celebration` (or the game's equivalent beats), keep the real gameplay UI visible and preserve the game's aspect ratio inside the frame.

| Slot | Size (px) |
|---|---|
| Android phone (Google Play) | 1080 × 1920 |
| iPhone 6.9" | 1320 × 2868 |
| iPad 13" | 2064 × 2752 |
| Google Play Feature Graphic | 1024 × 500 |
| Apple Product Page Header | 3840 × 1646 |
| Apple Search Results | 3840 × 2560 |
| Apple Universal Cover | 5244 × 2950 |

Plus shared masters: a landscape hero (~1536×1024) and portrait hero (~1024×1536) as full-bleed illustrated backgrounds with the painted title and mascot placed in safe zones, leaving one side empty to composite the screenshot. App icon at 1024 and 512.

## 7. Verification gates (run all before declaring "shipped")

1. Godot import + `--check-only` on every script → PASS.
2. Project test runner (if present) → exit 0.
3. Native APK: `apksigner verify`, ZIP integrity, four locales present, package version, `check_apk.py` (authorities unique).
4. Web build: load `index.html` in Chromium at 390×844 and 1280×800; confirm all locales start, tutorial/play works, save persists after reload, zero console errors, `.wasm`/`.pck`/`.js` MIME correct when served over HTTPS.
5. WebView APK: confirm `classes.dex`, `assets/web/index.html`, `assets/web/index.wasm`, `assets/web/index.pck` present and correct MIME.
6. Marketing PNGs: dimensions, placement, no foreground overlap/clipping.

## 8. Gotchas

- **No `.dll` in this stack** — Godot native code is `.so` (Android) and `.wasm` (Web). Don't expect or bundle any DLL.
- **No `.aab`** unless the Play Store requires it; this flow ships `.apk`.
- WebView APK needs `usesCleartextTraffic="true"` because the loopback server is plain HTTP.
- Keep the **same signing certificate** across native APK and WebView APK so they can replace each other.
- Web hosting requires HTTPS + correct `.wasm` MIME; single-threaded export avoids COOP/COEP headers.
- Always exclude editor/test scripts from release exports.
