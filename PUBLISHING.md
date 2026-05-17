# Publishing Hunger Cafe

Step-by-step guide for shipping the app to the **Google Play Store** (Android) and as **desktop builds** (macOS, Windows, Linux).

Two things to handle before either path:

1. **Backend must be deployed first.** Your Flutter app talks to the Node.js API via `API_BASE_URL`. While developing, you used `http://localhost:4000` — that won't work on a phone or a customer's laptop. The server has to be reachable on the public internet over HTTPS.
2. **Add the missing platforms.** Your project today only has `macos/` and `web/`. We need to add `android/` (and optionally `windows/` and `linux/`).

---

## Part 0 — Deploy the backend (do this first)

Pick any host that runs Node.js. Easiest options:

- **Render** (`render.com`) — free tier, deploys from GitHub, gives you HTTPS automatically.
- **Railway** (`railway.app`) — similar, easy MongoDB add-on.
- **Fly.io** — global edge, free allowance.
- **DigitalOcean App Platform** — $5/mo droplet equivalent.

Steps (same on any of them):

1. Push the `hunger` repo to GitHub.
2. Create a managed MongoDB cluster (MongoDB Atlas has a free M0 tier — `cloud.mongodb.com`). Copy the connection string.
3. In your host, create a new web service pointing at the `backend/` folder.
4. Set environment variables in the host's dashboard:
   - `MONGO_URI` = your Atlas connection string
   - `JWT_SECRET` = a long random string (`openssl rand -hex 48`)
   - `NODE_ENV` = `production`
   - `ALLOWED_ORIGINS` = your frontend origin once deployed (web build URL or `*` only during testing)
5. Set the build command to `npm install` and the start command to `npm start`.
6. After deploy, hit `https://your-app.onrender.com/health` — should return `{"status":"ok"}`.
7. From a local machine, run the seed once against the production DB so users and the menu exist:
   ```bash
   cd backend
   MONGO_URI="<your atlas uri>" JWT_SECRET="anything" npm run seed
   ```

You now have a production URL — note it, you'll bake it into the app builds below.

---

## Part 1 — Publish to Google Play Store

### 1.1 Add the Android platform to the project

```bash
cd frontend
flutter create --platforms=android --org com.hungercafe .
```

This creates the `android/` folder with the package `com.hungercafe.hunger_cafe`. Pick the package name carefully — **you cannot change it once published**.

### 1.2 Configure app identity

Edit `frontend/android/app/build.gradle`:

```gradle
android {
    namespace "com.hungercafe.hunger_cafe"
    compileSdk flutter.compileSdkVersion

    defaultConfig {
        applicationId "com.hungercafe.hunger_cafe"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
}
```

Bump `versionCode` (integer) **every** time you upload a new build to Play.

### 1.3 Add an app icon

Replace the generated icons. The easiest path is the `flutter_launcher_icons` package:

```yaml
# pubspec.yaml — under dev_dependencies
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/logo.png"      # use your real PNG, not the SVG
  adaptive_icon_background: "#FAF3E5"
  adaptive_icon_foreground: "assets/logo.png"
```

Then:

```bash
flutter pub get
dart run flutter_launcher_icons
```

### 1.4 Generate a release signing key

This signs your app. **Lose this file and you can never update your app on Play again** — back it up.

```bash
keytool -genkey -v -keystore ~/hunger-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Create `frontend/android/key.properties` (DO NOT commit this file):

```
storePassword=<the password you chose>
keyPassword=<the password you chose>
keyAlias=upload
storeFile=/Users/<you>/hunger-upload.jks
```

Add `key.properties` to `.gitignore`.

### 1.5 Wire signing into the Gradle build

At the top of `frontend/android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Inside `android { … }` add:

```gradle
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
```

### 1.6 Build the release bundle

Use your production API URL here:

```bash
cd frontend
flutter build appbundle \
  --release \
  --dart-define=API_BASE_URL=https://your-backend.onrender.com
```

The output is at `frontend/build/app/outputs/bundle/release/app-release.aab`. That AAB is what you upload to Play.

### 1.7 Set up the Play Console listing

1. Create a developer account at `play.google.com/console` (one-time **$25** fee).
2. Click **Create app** → name "Hunger Cafe", category Food & Drink, free.
3. Complete the required policies (privacy policy URL, content rating questionnaire, target audience, data safety form, ads declaration). The data-safety form needs honest answers about what your app collects — for Hunger you'll declare login email + name, transmitted over HTTPS.
4. Under **Main store listing**: app name, short description (80 chars), full description (4000 chars), 2-8 phone screenshots (1080×1920 typical), 1024×500 feature graphic, 512×512 high-res icon.
5. Under **Production** (or start with **Internal testing** — recommended for the first build):
   - Create a release → upload your `.aab`.
   - Fill in **Release notes**.
   - Roll out.
6. Submit for review. First reviews typically take 1–7 days; updates often go faster.

> Tip: ship to the **Internal testing** track first (only allowed testers see it) so you can confirm signing/build/store metadata before exposing anything publicly.

---

## Part 2 — Build as a desktop app

The same Flutter codebase compiles to native desktop binaries. You already have `macos/`; we'll add Windows and Linux as needed.

### 2.1 Enable desktop platforms (one-time, per machine)

```bash
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
```

### 2.2 Add Windows and Linux folders to the project

You can only generate the Windows folder from a Windows machine, and Linux from Linux/macOS:

```bash
cd frontend
flutter create --platforms=windows,linux .
```

### 2.3 Build the binaries

```bash
# macOS — produces frontend/build/macos/Build/Products/Release/Hunger Cafe.app
flutter build macos --release \
  --dart-define=API_BASE_URL=https://your-backend.onrender.com

# Windows — produces frontend/build/windows/x64/runner/Release/hunger_cafe.exe
flutter build windows --release \
  --dart-define=API_BASE_URL=https://your-backend.onrender.com

# Linux — produces frontend/build/linux/x64/release/bundle/hunger_cafe
flutter build linux --release \
  --dart-define=API_BASE_URL=https://your-backend.onrender.com
```

Each command must be run on its respective OS (you can't cross-compile Windows from macOS).

### 2.4 Distribute the desktop builds

**macOS**

- For team / internal use: zip the `.app` and share. Users will need to right-click → Open the first time (Gatekeeper warning).
- For public distribution: enroll in the Apple Developer Program (**$99/year**), code-sign the app, notarize it with Apple, then wrap as a `.dmg`. Or submit to the Mac App Store (same dev account).

**Windows**

- Easiest: bundle the contents of `build/windows/x64/runner/Release/` into an MSIX or use **Inno Setup** to build a `.exe` installer.
- For the Microsoft Store: package as MSIX with `msix` Dart package (`dart pub global activate msix`) and submit via Partner Center.

**Linux**

- Easiest: tar up `build/linux/x64/release/bundle/` and ship.
- Better: package as a Snap (`snapcraft`), Flatpak, or AppImage. Snap publishes to the Snap Store; AppImage runs anywhere without install.

### 2.5 Window size and behavior

Right now the app uses Flutter's default desktop window. To pin a sensible size and title on macOS, edit `frontend/macos/Runner/MainFlutterWindow.swift`:

```swift
self.contentViewController = flutterViewController
self.setFrame(NSRect(x: 0, y: 0, width: 1280, height: 800), display: true)
self.center()
self.title = "Hunger Cafe"
```

Equivalent files exist for Windows (`windows/runner/main.cpp`) and Linux (`linux/my_application.cc`).

---

## Recommended order

1. Deploy the backend, confirm `/health` works over HTTPS.
2. Pick a permanent Android package name and **don't change it**.
3. Build the AAB and ship to the Internal Testing track first; iterate on icons / screenshots / store copy without burning your production release.
4. In parallel, run `flutter build macos` for an offline-friendly desktop demo while the Play review is in flight.
5. After Internal Testing looks good, promote the same build to Production.

## Costs to budget

| Item | Cost |
|---|---|
| Google Play developer account | **$25** one-time |
| MongoDB Atlas (M0) | free |
| Render / Railway free tier | free (small) → ~$7–25/mo when you outgrow it |
| Apple Developer Program (only if signing macOS app for public release) | $99/year |
| Microsoft Partner Center (only if publishing to MS Store) | one-time $19 individual / $99 company |
| Windows code-signing cert (optional, avoids SmartScreen warnings) | $80–400/year |
