# Supabase Setup Guide for Fractured Reality

## 1. Create Supabase Project (Free)

1. Go to https://supabase.com
2. Click "Start your project" (sign up with GitHub)
3. Create a new organization (free)
4. Click "New Project"
   - Name: `fractured-reality`
   - Database Password: (generate and save this!)
   - Region: Choose closest to you
   - Pricing Plan: **Free** (500MB database, 50K MAU)
5. Wait 2-3 minutes for project to be ready

## 2. Get Your Credentials

Once project is ready:

1. Go to Project Settings (gear icon) → API
2. Copy these values:
   - **Project URL**: `https://xxxxx.supabase.co`
   - **anon/public key**: `eyJhbGc...` (long token)

You'll need these for `autoload/account_manager.gd`

## 3. Set Up Database Tables

Go to SQL Editor and run this:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table (extends Supabase auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  is_online BOOLEAN DEFAULT false
);

-- Friends table
CREATE TABLE public.friends (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  friend_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, friend_id)
);

-- Lobbies table
CREATE TABLE public.lobbies (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  host_username TEXT NOT NULL,
  player_count INTEGER NOT NULL DEFAULT 1,
  max_players INTEGER NOT NULL DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lobbies ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Public profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Friends policies
CREATE POLICY "Users can view their friends"
  ON public.friends FOR SELECT
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

CREATE POLICY "Users can send friend requests"
  ON public.friends FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update friend requests sent to them"
  ON public.friends FOR UPDATE
  USING (auth.uid() = friend_id);

CREATE POLICY "Users can delete their friend relationships"
  ON public.friends FOR DELETE
  USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Lobbies policies
CREATE POLICY "Anyone can view lobbies"
  ON public.lobbies FOR SELECT
  USING (true);

CREATE POLICY "Authenticated users can create lobbies"
  ON public.lobbies FOR INSERT
  WITH CHECK (auth.uid() = host_id);

CREATE POLICY "Hosts can update their lobbies"
  ON public.lobbies FOR UPDATE
  USING (auth.uid() = host_id);

CREATE POLICY "Hosts can delete their lobbies"
  ON public.lobbies FOR DELETE
  USING (auth.uid() = host_id);

-- Function to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', SPLIT_PART(NEW.email, '@', 1))
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for updated_at on profiles
CREATE TRIGGER on_profile_updated
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
```

## 4. Enable Realtime (for online status)

1. Go to Database → Replication
2. Enable replication for these tables:
   - `profiles` (for online status updates)
   - `friends` (for real-time friend updates)
   - `lobbies` (for real-time lobby updates)

## 5. Update Godot Configuration

Edit `autoload/account_manager.gd`:

```gdscript
const SUPABASE_URL := "https://your-project-id.supabase.co"
const SUPABASE_ANON_KEY := "your-anon-key-here"
```

## 6. Authentication Flow

Supabase handles:
- ✅ Password hashing (bcrypt)
- ✅ Session tokens (JWT)
- ✅ Email verification (optional)
- ✅ Password reset (optional)
- ✅ OAuth providers (Google, GitHub, etc.)

Your game just calls:
- `supabase.auth.sign_up()` - Register
- `supabase.auth.sign_in()` - Login
- `supabase.auth.sign_out()` - Logout
- `supabase.auth.session()` - Get current user

## 7. Cost Breakdown (Free Tier)

| Feature | Free Tier Limit | Your Usage | Status |
|---------|----------------|------------|--------|
| Database | 500 MB | ~1 MB | ✅ Plenty |
| Monthly Active Users | 50,000 | <100 | ✅ Plenty |
| API Requests | Unlimited | - | ✅ Free |
| Realtime Connections | 200 concurrent | ~10 | ✅ Plenty |
| Storage | 1 GB | 0 MB | ✅ Free |
| Bandwidth | 5 GB | <100 MB | ✅ Free |

**Result: Completely free for your game!**

## 8. Benefits Over Custom Backend

| Feature | Custom Node.js | Supabase |
|---------|---------------|----------|
| Hosting | Need to pay/deploy | Free (managed) |
| Database | SQLite (limited) | PostgreSQL (powerful) |
| Authentication | Custom (insecure) | Built-in (secure) |
| Realtime | Need Socket.IO | Built-in |
| Security | Manual | Row Level Security |
| Backups | Manual | Automatic |
| Scaling | Manual | Automatic |

## 9. Optional: Enable OAuth

For Steam/Discord/Google login later:

1. Go to Authentication → Providers
2. Enable desired providers
3. Configure OAuth credentials
4. Update login UI with OAuth buttons

## 10. Troubleshooting

**Can't connect from Godot?**
- Check your anon key is correct
- Verify project URL has no trailing slash
- Check if Row Level Security policies are correct

**Friend requests not working?**
- Check RLS policies in Supabase dashboard
- Verify user is authenticated (session exists)

**Realtime not updating?**
- Enable replication for tables in Database → Replication
- Subscribe to correct channels in Godot

## Next Steps

After setup:
1. Update `autoload/account_manager.gd` with your credentials
2. Test registration/login
3. Test friends system
4. Add online status tracking
5. Deploy and play!
