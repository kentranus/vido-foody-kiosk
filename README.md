# Vido Foody Kiosk App

Separate Flutter kiosk app package for customer self-order.

## Folders

- `vido-foody-kiosk/` - Flutter Android kiosk app.
- `docs/` - Platform and PAX/POSLink notes.
- `.github/workflows/` - GitHub Actions workflow to build the kiosk APK.

## Build Kiosk APK On GitHub

Upload this whole folder to a GitHub repo. Then open:

```text
Actions -> Build Vido Foody Kiosk APK -> Run workflow
```

The APK will be in the workflow artifact:

```text
vido-foody-kiosk-debug-apk
```

## Local Run

```bash
cd vido-foody-kiosk
flutter create .
flutter pub get
flutter run
```

## Kiosk Settings

The kiosk app supports portrait standing kiosks and landscape kiosks. The POS app should manage kiosk device/payment settings centrally. Each kiosk uses its own `Device ID` and assigned PAX terminal.
