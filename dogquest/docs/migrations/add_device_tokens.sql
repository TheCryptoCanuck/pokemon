-- Migration: device_tokens table for FCM push fan-out
-- Required for lost dog alert fan-out Edge Function.
-- Run in Supabase SQL editor before deploying the Edge Function.

CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  last_seen_lat DOUBLE PRECISION,
  last_seen_lon DOUBLE PRECISION,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, token)
);

CREATE INDEX IF NOT EXISTS device_tokens_user_id_idx ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS device_tokens_location_idx
  ON device_tokens(last_seen_lat, last_seen_lon)
  WHERE last_seen_lat IS NOT NULL AND last_seen_lon IS NOT NULL;

-- RLS: users can only read/write their own tokens
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own tokens" ON device_tokens
  FOR ALL USING (auth.uid() = user_id);
