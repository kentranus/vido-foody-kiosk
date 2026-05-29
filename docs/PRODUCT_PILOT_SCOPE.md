# Vido Foody Product Pilot Scope

This document defines what is needed before Vido Foody POS is used by real pilot customers.

## Product Direction

- Production app: Flutter tablet app.
- Backend/API: Node.js.
- React/Capacitor prototype: reference only, not production direction.

## Pilot Can Start When These Are Complete

1. Flutter app can create orders, take cash/gift card, and save orders to Node backend.
2. Card Payment works through PAX POSLink on the real Android POS/tablet.
3. Card void/refund works through PAX or processor-approved flow.
4. Receipt printer works through Android native MethodChannel.
5. Cash drawer opens through printer kick command.
6. Customer display works when a second screen exists and auto-disables on one-screen tablets.
7. Orders, reports, settings, online orders, settlements, and menu data persist after backend restart.
8. Manager approval is required for refunds, voids, discounts, and payment settings.
9. Online orders from `https://vidocenter.com/foody/` can enter the backend queue.
10. Settlement/batch close is tested with the actual processor/merchant account.

## Current Package Status

Included:

- Flutter POS UI starting point.
- Node.js backend with JSON file persistence.
- Backend endpoints for account login, store accounts, device registration, menu, settings, orders, online orders, kiosk orders, reports, payment sale, batch close, refund, and void.
- Online order accept/reject/print flow.
- Kiosk order creation flow.
- Separate Vido Foody Kiosk Flutter app with per-device PAX settings.
- Server-Sent Events for realtime POS queue updates.
- GitHub Actions for Flutter + Node checks.
- PAX/POSLink integration notes.

Not complete:

- Native Android PAX POSLink MethodChannel implementation in Flutter project.
- Native receipt printer and cash drawer MethodChannels.
- Native customer display MethodChannel.
- Real production database.
- Full manager approval workflow.
- Online payment provider integration for website checkout.
- Flutter login UI and authenticated API client wiring.
- Native Android POSLink wiring inside the Flutter kiosk app.
- Kitchen display and printer routing.

## Recommended Pilot Rule

Use this with one internal store first. Do not give it to outside customers until PAX sale, refund, void, receipt printing, cash drawer, and settlement are tested on the exact hardware and merchant account.
