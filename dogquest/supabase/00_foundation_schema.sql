-- ============================================================
-- DogQuest — Phase 0: Foundation Schema (TASK-002 + TASK-003)
-- Run this in the Supabase SQL Editor as a single script.
-- Creates: users, dog_profiles, sightings + indexes + RLS policies
-- Idempotent: drops existing tables first.
-- ============================================================

-- Clean slate: drop everything in reverse dependency order
DROP FUNCTION IF EXISTS update_updated_at() CASCADE;
DROP POLICY IF EXISTS "sightings_own" ON sightings;
DROP POLICY IF EXISTS "dog_profiles_delete" ON dog_profiles;
DROP POLICY IF EXISTS "dog_profiles_update" ON dog_profiles;
DROP POLICY IF EXISTS "dog_profiles_write" ON dog_profiles;
DROP POLICY IF EXISTS "dog_profiles_read" ON dog_profiles;
DROP POLICY IF EXISTS "users_own_profile" ON users;
DROP TABLE IF EXISTS sightings CASCADE;
DROP TABLE IF EXISTS dog_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================
-- TABLE: users
-- ============================================================
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT auth.uid(),
  email TEXT UNIQUE NOT NULL,
  username TEXT UNIQUE NOT NULL,
  display_name TEXT,
  avatar_id TEXT DEFAULT 'default',
  level INTEGER DEFAULT 1,
  total_xp INTEGER DEFAULT 0,
  total_sightings INTEGER DEFAULT 0,
  kennel_count INTEGER DEFAULT 0,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_active_date DATE,
  location_sharing_enabled BOOLEAN DEFAULT false,
  approximate_lat DOUBLE PRECISION,
  approximate_lon DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- TABLE: dog_profiles
-- ============================================================
CREATE TABLE dog_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  breed TEXT NOT NULL,
  breed_secondary TEXT,
  photo_url TEXT,
  date_of_birth DATE,
  weight_kg DOUBLE PRECISION,
  sex TEXT CHECK (sex IN ('male', 'female', 'unknown')),
  is_neutered BOOLEAN,
  bio TEXT,
  temperament_tags TEXT[],
  is_lost BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_dog_profiles_owner ON dog_profiles(owner_id);
CREATE INDEX idx_dog_profiles_breed ON dog_profiles(breed);
CREATE INDEX idx_dog_profiles_lost ON dog_profiles(is_lost) WHERE is_lost = true;

-- ============================================================
-- TABLE: sightings
-- ============================================================
CREATE TABLE sightings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  breed_name TEXT NOT NULL,
  confidence DOUBLE PRECISION NOT NULL,
  top3_breeds JSONB,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  location_accuracy DOUBLE PRECISION,
  photo_url TEXT,
  xp_earned INTEGER DEFAULT 0,
  is_new_breed BOOLEAN DEFAULT false,
  rarity TEXT CHECK (rarity IN ('common', 'uncommon', 'rare', 'legendary', 'unknown')),
  local_id TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_sightings_user ON sightings(user_id);
CREATE INDEX idx_sightings_breed ON sightings(breed_name);
CREATE INDEX idx_sightings_created ON sightings(created_at DESC);
CREATE INDEX idx_sightings_local_id ON sightings(local_id);

-- ============================================================
-- TASK-002 complete. Now TASK-003: RLS policies.
-- ============================================================

-- Enable RLS on all three tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE dog_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE sightings ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS: users — read/update own profile only
-- ============================================================
CREATE POLICY "users_own_profile" ON users
  USING (auth.uid() = id);

-- ============================================================
-- RLS: dog_profiles — readable by all authenticated users
-- ============================================================
CREATE POLICY "dog_profiles_read" ON dog_profiles
  FOR SELECT USING (auth.role() = 'authenticated');

-- RLS: dog_profiles — writable only by owner
CREATE POLICY "dog_profiles_write" ON dog_profiles
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "dog_profiles_update" ON dog_profiles
  FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "dog_profiles_delete" ON dog_profiles
  FOR DELETE USING (auth.uid() = owner_id);

-- ============================================================
-- RLS: sightings — visible and writable by owner only
-- ============================================================
CREATE POLICY "sightings_own" ON sightings
  USING (auth.uid() = user_id);

-- ============================================================
-- Updated_at trigger (auto-update on row modification)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER dog_profiles_updated_at
  BEFORE UPDATE ON dog_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
