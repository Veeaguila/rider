# Rider App

This Flutter app is the courier-facing mobile client for the existing ALONA Laravel API in [`../alona-ecommerce-integration`](../alona-ecommerce-integration/). ALONA remains the single backend and database.

## Requirements

- Flutter and Dart versions supported by `pubspec.yaml`
- Android Studio with an Android emulator, or a connected Android device
- A running ALONA API and its existing database

## Install dependencies

Run these commands from the Rider project:

```powershell
flutter pub get
```

Start the existing Laravel API by following [`../alona-ecommerce-integration/README.md`](../alona-ecommerce-integration/README.md). Then launch the app with the API URL for your target device:

### Android emulator

The Android emulator reaches services on the development computer through `10.0.2.2`:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

### Web, desktop, or iOS simulator on the same computer

```powershell
flutter run --dart-define=API_BASE_URL=http://localhost:8000/api
```

### Physical device

Connect the device and development computer to the same trusted network. Start Laravel so it listens on the network interface:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Then replace `<computer-lan-ip>` with the computer's LAN address:

```powershell
flutter run --dart-define=API_BASE_URL=http://<computer-lan-ip>:8000/api
```

Allow port 8000 through the local firewall only on the trusted development network. Android permits cleartext HTTP for debug builds only; production deployments should use HTTPS.

## Structure

| Path | Purpose |
| --- | --- |
| `lib/pages` | Registration, login, pickup, delivery, and proof screens |
| `lib/services` | API configuration and shared service code |
| `assets/images` | App images |
| `android`, `ios`, `web`, `windows`, `macos`, `linux` | Flutter platform projects |
| `test` | Flutter tests |

Debug builds default to http://localhost:8000/api. Supply API_BASE_URL for emulators or devices; localhost refers to the device itself. Trailing slashes are normalized. Release builds require an explicit HTTPS URL ending in /api:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://<alona-host>/api
```

The public GET /api/sorting-centers endpoint can verify connectivity without logging in or changing database records. Its data list may be empty. Flutter web also requires the server to permit the application's origin through CORS.
