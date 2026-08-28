# credilink_flutter

Flutter implementation of CrediLink v2.

## Invoke in Cursor

Use **/credilink-flutter** or **@credilink-flutter**

## Docs & requirements

| Folder | Purpose |
|--------|---------|
| [`requirements/credilink-v2/`](../requirements/credilink-v2/) | What to build (shared) |
| [`requirements/credilink-v2/FLUTTER.md`](../requirements/credilink-v2/FLUTTER.md) | Flutter structure & routes |
| [`docs/flutter/`](../docs/flutter/) | Implementation docs |

## Run

```bash
cd credilink_flutter
flutter pub get
flutter run -d chrome
```

## Features implemented

- Landing (`/home`)
- Auth: login, register, forgot password, reset password
- Role tab shells: Admin, StoreOwner, Employee, Customer (5 tabs each)
- Shared widgets: auth kit, PhAddressPicker, DebtCalendar, PaymentSheet, BarcodeInputCard
- Repositories: Auth, Admin, Store, Product, Payment, Customer, Employee, Location
- Route guards per role
- Firebase Auth + Firestore (v2 security)

## Firebase

Project `credilink-ad684`. Pin `firebase_core ^3.13.x` for Dart 3.11 web compatibility.
