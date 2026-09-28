# Implementation Plan - Centralized Auth & Password Management

This plan implements a secure login system shared between the website and the Flutter app, including a "Change Password" feature in the settings.

## User Review Required

> [!IMPORTANT]
> - After the backend changes are applied, the first login will use a default credential:
>   - **ID**: `admin`
>   - **Password**: `admin123`
> - You **MUST** change this password immediately after the first login via the app's Settings screen.
> - The backend will now require a valid JWT token for all data operations. This means the existing website might need a small update to handle the login flow if it wasn't already implemented.

## Proposed Changes

---

### [Component] Backend (Node.js/Express)

Implement the authentication logic and protect existing routes.

#### [NEW] [auth.js](file:///C:/Users/Rahul/Desktop/sabji_setu/server/routes/auth.js)
- Create `/login` endpoint to verify credentials and return a JWT.
- Create `/change-password` endpoint to verify the current password and update to a new one.
- Implement a middleware to verify JWT tokens.

#### [MODIFY] [index.js](file:///C:/Users/Rahul/Desktop/sabji_setu/server/index.js)
- Register the `authRouter`.
- Add a table initialization for `users` and a default admin user.
- Apply the auth middleware to protect all `/api` routes (except `/auth/login`).

---

### [Component] Flutter Core (Logic & Client)

Update the API client to handle security tokens.

#### [MODIFY] [api_client.dart](file:///C:/Users/Rahul/Desktop/sabji_setu/lib/core/api_client.dart)
- Add token storage using `shared_preferences`.
- Add `login`, `logout`, and `changePassword` methods.
- Update `_request` to include the `Authorization: Bearer <token>` header automatically.

---

### [Component] Flutter UI (Screens)

Create the login flow and update settings.

#### [NEW] [login_screen.dart](file:///C:/Users/Rahul/Desktop/sabji_setu/lib/screens/login_screen.dart)
- Premium themed login page with validation.
- Handles token storage on successful login.

#### [MODIFY] [app.dart](file:///C:/Users/Rahul/Desktop/sabji_setu/lib/app.dart)
- Update the `home` logic: Check for a stored token. If exists, show `SplashScreen` (which goes to `HomeShell`); otherwise, show `LoginScreen`.

#### [MODIFY] [home_shell.dart](file:///C:/Users/Rahul/Desktop/sabji_setu/lib/screens/home_shell.dart)
- Add a "Logout" button at the bottom of the sidebar.

#### [MODIFY] [settings_screen.dart](file:///C:/Users/Rahul/Desktop/sabji_setu/lib/screens/settings_screen.dart)
- Add a new "Security" tab.
- Implement the "Change Password" form with 3 fields (Current, New, Confirm).
- Logically connect it to the `api.changePassword` method.

## Verification Plan

### Automated Tests
- Run `flutter analyze` to ensure no syntax errors.

### Manual Verification
1. **Initial Login**: Done.
2. **Persistence**: Done.
3. **Change Password**: Done.
4. **Logout**: Done.
5. **Item Master Toggle**:
   - Go to Settings -> Item Master.
   - Disable an item (e.g., 'Apple').
   - Go to Mandi Purchase -> Add.
   - Type 'App'. Apple should NOT appear in suggestions.
   - Re-enable Apple in settings.
   - Type 'App' again. Apple SHOULD appear.
