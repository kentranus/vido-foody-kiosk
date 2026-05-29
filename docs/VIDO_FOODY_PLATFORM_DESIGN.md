# Vido Foody Platform Design

This is the target design for Vido Foody as a shared restaurant ordering platform.

## Product Pieces

```text
Vido Foody Cloud / Store Backend
  - accounts, stores, menus, orders, payments, reports, devices

Vido Foody POS App
  - Flutter Android tablet app for staff/counter

Vido Foody Kiosk App
  - Flutter Android kiosk app for self-ordering
  - auto-adapts to portrait standing kiosks and landscape tabletop kiosks

Vido Foody Online Ordering Website
  - customer web ordering link per store

Local Hardware
  - PAX/card terminals
  - receipt printers
  - kitchen printers/KDS
  - cash drawers
  - customer displays
```

## Store Account Model

Each shop has one store account.

```text
Store ID: store_abc123
Slug: abc-boba
Owner login: owner@example.com
Online order link: https://vidocenter.com/foody/abc-boba
Subscription: active / trial / suspended
```

App startup:

1. POS or kiosk opens.
2. If no valid session token exists, show login.
3. Owner/staff logs in.
4. App downloads store settings, menu, payment settings, printer routing, and device config.
5. App registers the device ID.

Kiosk payment settings should be managed inside the POS Settings screen. The kiosk app should only need its `Device ID` and backend/store connection, then it can download its assigned terminal config.

## Device Model

Every device should register with the backend.

```text
POS-1
Kiosk-1
Kiosk-2
KitchenDisplay-1
ReceiptPrinter-1
KitchenPrinter-1
PAX-Counter
PAX-Kiosk-1
```

Device fields:

```json
{
  "deviceId": "KIOSK-1",
  "type": "kiosk",
  "name": "Front Kiosk 1",
  "storeId": "store_abc123",
  "status": "online",
  "lastSeenAt": "..."
}
```

Kiosk terminal config example:

```json
{
  "deviceId": "KIOSK-1",
  "name": "Front Kiosk 1",
  "enabled": true,
  "connectionMode": "tcp",
  "terminalIp": "192.168.68.59",
  "terminalPort": 10009,
  "timeoutMs": 60000,
  "requirePaymentBeforeSend": true
}
```

## Order Sources

All orders enter the same backend queue with a source.

```text
POS
Online
Kiosk-KIOSK-1
Kiosk-KIOSK-2
DoorDash
UberEats
```

Order statuses:

```text
pending_accept
accepted
new
preparing
ready
completed
rejected
cancelled
refunded
voided
```

## Online Ordering Flow

Online order should not print automatically unless configured.

```text
Customer opens https://vidocenter.com/foody/{storeSlug}
→ Customer orders and pays online or selects pay at store
→ Backend creates order with source=Online, status=pending_accept
→ POS receives realtime event
→ Owner taps Accept
→ Backend marks shouldPrint=true
→ POS/local print service prints ticket
→ Staff prepares order
```

Reject flow:

```text
Owner taps Reject
→ Backend marks rejected
→ Online payment refund must be triggered if already paid
→ No kitchen ticket prints
```

## Kiosk Ordering Flow

Kiosk is in-store, so paid kiosk orders can auto-print.

```text
Customer orders on kiosk
→ Kiosk sends payment to its assigned PAX terminal
→ Payment approved
→ Kiosk posts order to /api/kiosk/orders
→ Backend creates source=Kiosk-{deviceId}, status=new, shouldPrint=true
→ POS/local print service receives realtime event
→ Ticket prints
→ Staff prepares order
```

Store setting:

```text
autoPrintKioskPaidOrders: true/false
```

## Payment Design

POS:

```text
Cash
Card Payment via counter PAX
Gift Card
```

Kiosk:

```text
Add tip on kiosk screen
Pay Now via kiosk PAX terminal
Paid order sends to POS/backend and should print at POS
Optional phone entry after payment for receipt
```

Website:

```text
Online gateway such as Stripe/Square/Authorize.Net
Pay at Store optional
```

PAX is for in-store POS/kiosk card present payment. Website card-not-present payment should use an online gateway.

## Printing Rules

```text
POS order:
  Print after cashier sends/complete payment.

Online order:
  Print only after owner accepts.

Kiosk paid order:
  Auto print after payment approved when autoPrintKioskPaidOrders=true.

Reprint:
  Available from Order History.
```

Printer routing:

```text
Drinks -> Bar printer
Snacks/Food -> Kitchen printer
Receipt -> Receipt printer
```

## Backend APIs Added For Platform

Auth:

```text
POST /api/auth/login
POST /api/auth/logout
GET  /api/auth/me
```

Stores/devices:

```text
GET  /api/stores/me
POST /api/admin/stores
POST /api/devices/register
GET  /api/devices
GET  /api/events
```

Public online ordering:

```text
GET  /api/public/stores/{slug}
POST /api/online-orders
```

POS order control:

```text
GET  /api/online-orders
POST /api/online-orders/{id}/accept
POST /api/online-orders/{id}/reject
POST /api/online-orders/{id}/print
```

Kiosk:

```text
POST /api/kiosk/orders
```

Reports:

```text
GET /api/reports/summary
```

## Realtime

The pilot backend exposes Server-Sent Events:

```text
GET /api/events
Authorization: Bearer {token}
```

Events:

```text
online_order.created
online_order.accept
online_order.reject
online_order.print
kiosk_order.created
order.created
order.refund
order.void
```

Flutter POS should keep this connection open and refresh the queue when events arrive.

## Pilot Backend Login

Default development login:

```text
email: owner@vidofoody.local
password: demo1234
```

Override with env vars:

```bash
VIDO_OWNER_EMAIL=owner@shop.com
VIDO_OWNER_PASSWORD=temporaryPassword
VIDO_ADMIN_SECRET=change-this-secret
npm start
```

The pilot backend uses simple SHA-256 password hashes and JSON file storage. Production must replace this with a real database, salted password hashing, rate limits, audit logs, and secure token/session handling.
