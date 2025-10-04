# Authentication System Review

## Current Implementation Overview

### Architecture
- **Backend**: Supabase (PostgreSQL + Auth)
- **Database Tables**:
  - `auth.users` (Supabase managed)
  - `public.profiles` (custom, auto-created via trigger)
  - `public.friends` (friend relationships)
  - `public.lobbies` (game sessions)

### Authentication Flow

**Registration:**
1. User enters `username` + `password` in UI
2. AccountManager generates email: `username@fractured-reality.local`
3. Sends to Supabase: `POST /auth/v1/signup`
   ```json
   {
     "email": "username@fractured-reality.local",
     "password": "password123",
     "data": {
       "username": "username"
     }
   }
   ```
4. Supabase creates user in `auth.users` table
5. Trigger `on_auth_user_created` fires
6. Profile auto-created in `public.profiles` with username

**Login:**
1. User enters `username` + `password` in UI
2. AccountManager generates email: `username@fractured-reality.local`
3. Sends to Supabase: `POST /auth/v1/token?grant_type=password`
4. Receives JWT access_token + refresh_token
5. Sets online status to `true`

## Issues Identified

### 🔴 CRITICAL: Email Domain Validation

**Problem**: Using fake email domain `@fractured-reality.local`

**Risks**:
- Supabase might reject non-standard email domains
- Email confirmation would fail (if enabled)
- Future email features (password reset) won't work

**Solutions**:
1. **Option A (Current)**: Disable email confirmation in Supabase settings
2. **Option B (Better)**: Use real email domain (e.g., `username@temp-mail.io`)
3. **Option C (Best)**: Add actual email field to UI and use real emails

**Status**: ⚠️ **MUST VERIFY** email confirmation is disabled in Supabase

### 🟡 WARNING: Security Function Search Path

**Problem**: Database functions missing `search_path` parameter

**Affected Functions**:
- `handle_new_user()` - Creates profile on signup
- `handle_updated_at()` - Updates timestamp

**Risk**: Low - These are SECURITY DEFINER functions which could be exploited

**Fix**:
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public  -- ADD THIS
AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### 🟢 WORKING: Other Components

✅ **Database Schema**: All tables created correctly with RLS
✅ **Row Level Security**: Policies configured properly
✅ **Triggers**: Auto-create profile trigger is correct
✅ **Friends System**: Query logic is sound
✅ **Session Persistence**: JWT tokens saved to disk

## Required Supabase Settings

### Email Settings (CRITICAL)

**Must configure in Supabase Dashboard:**

1. Go to **Authentication → Settings**
2. **Disable** "Enable email confirmations"
   - Otherwise users can't login without clicking email link
   - Our fake emails won't receive confirmation
3. **Disable** "Enable email change confirmations"
4. **Optional**: Set "Minimum password length" (currently 6)

**Or use this SQL to check current settings:**
```sql
SELECT * FROM auth.config;
```

### Auth Providers

✅ Email/Password provider is enabled by default

## Testing Checklist

Before testing, verify:

- [ ] **Supabase email confirmation is DISABLED**
- [ ] **Test with 2 game instances:**
  1. Instance 1: Register as "player1" / "password123"
  2. Instance 2: Register as "player2" / "password456"
  3. Instance 1: Add friend "player2"
  4. Instance 2: Accept friend request
  5. Verify online status shows correctly
- [ ] **Test session persistence:**
  1. Login
  2. Close game
  3. Reopen game
  4. Verify still logged in (currently NOT implemented)

## Recommendations

### Immediate (Before Testing)

1. **Verify Supabase email settings** - CRITICAL
   - Dashboard → Authentication → Settings
   - Disable email confirmations

2. **Fix security warnings** (optional but recommended)
   - Add `SET search_path = public` to functions

### Short-term Improvements

1. **Better email handling**
   - Use disposable email service (temp-mail.io)
   - Or add real email field to UI

2. **Implement session restore**
   - Currently tokens are saved but not used
   - Implement refresh_token logic in `_try_restore_session()`

3. **Add error handling**
   - Better error messages for failed registration
   - Handle duplicate usernames gracefully

### Long-term Enhancements

1. **OAuth Integration**
   - Steam Login (best for game)
   - Discord Login
   - Google Login

2. **Realtime Subscriptions**
   - Subscribe to friend status changes
   - Real-time friend request notifications
   - Lobby updates

3. **Password Reset**
   - Would require real emails
   - Or add security questions

## Current Status

**Database**: ✅ Configured and ready
**Authentication Logic**: ✅ Implemented
**Email Confirmations**: ⚠️ **MUST VERIFY DISABLED**
**Security**: 🟡 Minor warnings
**Tested**: ❌ Not yet tested

## How to Verify Email Settings

Run this in Supabase SQL Editor:

```sql
-- Check if email confirmation is required
SELECT
  COALESCE(
    (SELECT raw_app_meta_data->>'email_confirmed_at'
     FROM auth.users
     LIMIT 1),
    'No users yet - check dashboard settings'
  ) as email_confirmation_status;
```

Or manually:
1. Go to https://supabase.com/dashboard
2. Select your project
3. Authentication → Settings
4. Look for "Enable email confirmations" toggle
5. **MUST BE OFF** for fake emails to work

## Next Steps

1. ✅ Created database schema (DONE)
2. ✅ Implemented AccountManager (DONE)
3. ⚠️ **VERIFY email confirmation disabled**
4. ❌ Fix security warnings (optional)
5. ❌ Test authentication flow
6. ❌ Test friends system
7. ❌ Implement session restore
