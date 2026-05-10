-- Migration: add embedding column to lost_dog_reports
-- Required for stray scan to match against network reports.
-- embedding: JSON array of 150 floats (EfficientNetB2 softmax output).
-- Run this in the Supabase SQL editor before deploying the v6 build.

ALTER TABLE lost_dog_reports
  ADD COLUMN IF NOT EXISTS embedding JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Update the get_active_lost_dogs RPC to return the embedding column.
-- Must DROP first because the return type changes (adding embedding column).
DROP FUNCTION IF EXISTS get_active_lost_dogs(double precision, double precision, double precision);

CREATE OR REPLACE FUNCTION get_active_lost_dogs(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_radius_miles DOUBLE PRECISION DEFAULT 10
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  dog_profile_id UUID,
  dog_name TEXT,
  breed TEXT,
  photo_url TEXT,
  description TEXT,
  last_seen_lat DOUBLE PRECISION,
  last_seen_lon DOUBLE PRECISION,
  last_seen_at TIMESTAMPTZ,
  status TEXT,
  alert_radius_miles DOUBLE PRECISION,
  created_at TIMESTAMPTZ,
  resolved_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  distance_miles DOUBLE PRECISION,
  sighting_count BIGINT,
  embedding JSONB
)
LANGUAGE sql STABLE AS $$
  SELECT
    r.id,
    r.user_id,
    r.dog_profile_id,
    r.dog_name,
    r.breed,
    r.photo_url,
    r.description,
    r.last_seen_lat,
    r.last_seen_lon,
    r.last_seen_at,
    r.status,
    r.alert_radius_miles,
    r.created_at,
    r.resolved_at,
    r.expires_at,
    ST_Distance(
      ST_MakePoint(p_lon, p_lat)::geography,
      ST_MakePoint(r.last_seen_lon, r.last_seen_lat)::geography
    ) / 1609.34 AS distance_miles,
    COUNT(s.id) AS sighting_count,
    r.embedding
  FROM lost_dog_reports r
  LEFT JOIN lost_dog_sightings s ON s.report_id = r.id
  WHERE r.status = 'active'
    AND (r.expires_at IS NULL OR r.expires_at > NOW())
    AND ST_DWithin(
      ST_MakePoint(p_lon, p_lat)::geography,
      ST_MakePoint(r.last_seen_lon, r.last_seen_lat)::geography,
      p_radius_miles * 1609.34
    )
  GROUP BY r.id
  ORDER BY distance_miles ASC
$$;
