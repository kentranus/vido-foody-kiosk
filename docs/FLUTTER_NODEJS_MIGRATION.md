# Vido Foody Flutter + Node.js Migration

Production target:

- `vido-foody-flutter/` — Flutter tablet POS app.
- `vido-foody-backend/` — Node.js backend for menu/order/report/online-order APIs and TCP payment fallback.

Important: keep the same Vido Foody product, screens, labels, menu, report logic, PAX/payment behavior, customer display behavior, and hardware requirements. The goal is a technology migration, not a redesign.

The React/Capacitor app remains a reference only.

## Backend

```bash
cd vido-foody-backend
npm start
```

Default port is `8787`. If that port is already used:

```bash
PORT=8790 npm start
```

## Flutter

```bash
cd vido-foody-flutter
flutter create .
flutter pub get
flutter run
```

In Flutter Settings, set:

- Backend URL: `http://YOUR_SERVER_IP:8787`
- Payment Terminal IP: `192.168.68.59`
- Payment Terminal Port: `10009`

For Android local-network HTTP testing, add this to the generated Android manifest `application` tag:

```xml
android:usesCleartextTraffic="true"
```

## Card Payment

Preferred production payment implementation:

```text
Flutter Android MethodChannel
→ POSLink Java Android SDK
→ PAX/BroadPOS
```

Reserved MethodChannel:

```text
vido.foody/poslink
```

Native methods to implement:

```text
testConnection({ payment })
sale({ amount, refNum, tipAmount, payment })
batchClose({ payment, forceClose })
openCashDrawer({ printer })
printReceipt({ receipt })
customerDisplay({ state, order, config })
```

Node.js fallback for TCP/IP development:

```text
POST /api/payment/sale
```

The backend sends BroadPOS TCP to the terminal. USB payment cannot go through Node.js and must use Android POSLink native channel.

## Required Feature Parity

- 4-column POS sell screen.
- Touch-friendly category and Add buttons.
- Light/dark mode.
- Cash, Card Payment, and Gift Card tender names.
- Customer display/POS tip flow and PAX terminal tip mode.
- Open cash drawer button on main screen.
- Receipt print hook.
- Payment Settings with TCP/IP, USB, timeout, tip, and settlement.
- Manual Batch Close and auto settlement settings.
- Operations closeout.
- Reports: net/gross sales, orders, tax, tips, tender mix, refunds/voids.
- Online Orders queue for website/third-party orders.
- Staff/PIN module to be implemented with backend storage.
- Menu editor to be implemented with backend `/api/menu`.

## Backend APIs

```text
GET  /api/health
GET  /api/settings
POST /api/settings
GET  /api/menu
POST /api/menu
GET  /api/orders
POST /api/orders
GET  /api/online-orders
POST /api/online-orders
POST /api/online-orders/:id
GET  /api/reports/summary
POST /api/payment/test-connection
POST /api/payment/sale
POST /api/payment/batch-close
GET  /api/payment/settlements
POST /api/hardware/open-drawer
POST /api/receipt/print
```
