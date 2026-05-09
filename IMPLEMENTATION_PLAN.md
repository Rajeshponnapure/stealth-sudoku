# PIN Auth Repair & Security Enforcement Plan

## Goal
Fix the critical security flaw where any PIN allows access to the application. Ensure that login only succeeds if the **Username** and **PIN** match the ones used during registration, and prevent automatic account creation when random credentials are entered.

## Identified Issues
1. **Forced Local Unlock**: The `StealthUnlockPage` used `force: true`, bypassing local PIN verification.
2. **Navigation Leak**: authentication failure did not stop the app from navigating to the chat list.
3. **Implicit Registration**: `AuthService.signInToVault` automatically created new accounts for unknown devices.
4. **Missing Database Field**: The `profiles` table lacked a `secure_pin` column for server-side verification.
5. **Missing Identity Verification**: Login only required a PIN, not a username, making it easier to bypass.

## Phase 1: Database & Backend Hardening
1. **Database Schema Update**:
   - Added `secure_pin` and `room_id` to the `public.profiles` table.
   - Added `pin`, `nickname`, and `room_id` to the `public.devices` table for consistency.
   - Ensured `username` is unique in the `profiles` table.

2. **Modify `AuthService.signInToVault`**:
   - Updated to verify **both Username and Secure PIN** against the `profiles` table.
   - Now checks if `secure_pin` in DB matches the provided `pin`.
   - Strictly handles `allowRegistration` flag: login attempts for unknown users are rejected.

3. **Modify `AuthService._registerRoomPresence`**:
   - Now syncs data to both `profiles` (central identity) and `devices` (push link).
   - Saves the `secure_pin` to the database during registration.

## Phase 2: UI & Flow Enforcement
1. **Fix `StealthUnlockPage` Logic**:
   - Added **Username** field to the login UI.
   - Changed `unlock(pin, force: true)` to `unlock(pin, force: false)`.
   - Blocked navigation if `authService.signInToVault` fails.
   - Updated error messages: "Incorrect credentials. Please check your username and PIN."

2. **Update `StealthRegistrationPage`**:
   - Ensures it calls `signInToVault` with `allowRegistration: true`.
   - Saves the initial `secure_pin` and `nickname` to the database.

## Phase 3: Verification Steps
1. **Random Credentials Test**:
   - Enter a random username and PIN.
   - **Expected**: Error message "Account not found. Please register first."
2. **Wrong PIN Test**:
   - Register user `Alice` with PIN `123456`.
   - Try to login as `Alice` with `654321`.
   - **Expected**: Error message "Incorrect credentials..."
3. **Correct Credentials Test**:
   - Enter registered username and correct PIN.
   - **Expected**: Successful login and navigation.
