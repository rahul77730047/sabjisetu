# SabziSetu Flutter/Dart conversion

This ZIP converts the **React frontend** into a Flutter/Dart mobile frontend and keeps the existing **Express + PostgreSQL backend**. The backend should NOT be converted to Dart just to make a Flutter app.

## What is included
- Flutter app (`lib/`)
- Reusable Dart API client
- Dashboard
- CRUD-style mobile screens for Mandi Purchase, Local Purchase, Stock, Sales, Customers, Expenses, Labour
- WhatsApp Bills and Notifications list screens
- Business Settings screen
- Existing Node/Express/PostgreSQL backend in `server/`
- Original real `server/.env` is intentionally NOT copied. Use `.env.example`.

## Basic idea
Flutter -> HTTP API -> Express -> PostgreSQL. Flutter never connects directly to PostgreSQL. Supabase is not required for this project.

## First run
1. Install Flutter and PostgreSQL.
2. Create/import the database using `server/schema.sql`.
3. Copy `server/.env.example` to `server/.env` and put YOUR local development DATABASE_URL in it.
4. In the project root run `npm install`, then `npm run server`. The API should start on port 4000.
5. Check `http://localhost:4000/api/health` on the PC.
6. In Flutter project root run `flutter pub get`.
7. Start Android Emulator and run `flutter run`.

## Why API URL is 10.0.2.2
Android Emulator's localhost is the emulator itself. `10.0.2.2` points to the Windows host PC, so `http://10.0.2.2:4000/api` reaches your local Express server.

For a real phone, use a reachable LAN IP (during local testing) or preferably a deployed HTTPS development API.

## Important conversion note
The original `App.jsx` is ~1900 lines and contains desktop-specific UI, charts, browser downloads and WhatsApp browser behavior. Flutter uses different widgets and mobile UX, so a literal line-by-line JSX-to-Dart translation is neither correct nor useful. This project converts the architecture and core CRUD/API workflow into Flutter. Reports, Payments, backup/export and specialized WhatsApp behavior should be implemented as native Flutter screens based on the final Zaveri OS business requirements.

## Zaveri OS reuse
When you receive the real Zaveri OS backend, keep this Flutter architecture and replace SabziSetu resource names/models/screens with jewellery modules. Do not connect Flutter directly to PostgreSQL.
