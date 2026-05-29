# Vido Foody Kiosk

Separate Flutter Android kiosk app for customer self-order.

This app is for kiosk devices only. The tablet POS remains in `vido-foody-flutter/`.

## How It Works

1. Customer orders on the kiosk.
2. Customer adds tip on the kiosk screen.
3. Customer taps Pay Now.
4. Kiosk charges the customer's card on its assigned PAX terminal.
5. When payment is approved, kiosk sends the paid order to the Node.js backend.
6. POS receives the order in realtime and prints the ticket for staff.
7. Kiosk shows the order number and lets the customer enter a phone number for receipt.

## Screen Orientation

The kiosk UI automatically adapts to the screen shape.

- Landscape kiosk: menu and cart are shown side by side.
- Portrait kiosk: menu is shown on top, cart/checkout is docked at the bottom.

Use the same app for standing portrait kiosks and wide landscape kiosks.

## Kiosk Settings

Long-press the logo/welcome screen to open settings.

Each kiosk should have its own:

- `Backend URL`
- `Store Slug`
- `Kiosk Device ID`
- `Kiosk Name`
- `PAX Connection Mode`
- `PAX Terminal IP` for TCP/IP mode
- `PAX Terminal Port`, usually `10009`
- `Timeout`
- `Require payment before sending kiosk order`

## PAX Connection Options

### TCP/IP

Use this when the PAX terminal is on the same network.

Example:

```text
Backend URL: http://192.168.68.55:8787
Store Slug: vido-foody-demo
Kiosk Device ID: KIOSK-1
PAX Connection Mode: TCP/IP
PAX Terminal IP: 192.168.68.59
PAX Terminal Port: 10009
```

### USB

USB requires native Android POSLink work.

Flutter should call:

```text
MethodChannel: vido.foody/poslink
method: sale
method: testConnection
```

Then the Android side must use PAX POSLink Java Android SDK to talk to the terminal.

## Backend API

Kiosk paid orders are sent to:

```text
POST /api/kiosk/orders
```

The backend stores the order and notifies the POS through:

```text
GET /api/events
```

## Run

```bash
flutter create .
flutter pub get
flutter run
```

## Production Notes

This is a Flutter kiosk app starter for the dev team. Before real customer use, finish and test the Android POSLink MethodChannel on the exact PAX model, merchant account, and processor setup.
