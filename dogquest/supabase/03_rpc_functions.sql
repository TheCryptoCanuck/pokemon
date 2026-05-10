-- ============================================================
-- DogQuest — Phase 1: RPC Functions (TASK-017)
-- Run this in the Supabase SQL Editor AFTER 02_social_rls_policies.sql.
-- 5 functions: get_feed, get_dogs_nearby, get_active_lost_dogs,
--              sync_sightings, get_leaderboard
-- ============================================================

-- ============================================================
-- Feed: Get paginated social feed for a user
-- SUPA-001 (2026-05-10): dropped p_user_id — caller was trusted. Now derives
-- identity from auth.uid() server-side so no client can impersonate another user.
-- ============================================================
CREATE OR REPLACE FUNCTION get_feed(
  p_limit INTEGER DEFAULT 20,
  p_cursor TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  username TEXT,
  display_name TEXT,
  avatar_id TEXT,
  post_type TEXT,
  content TEXT,
  breed_name TEXT,
  photo_url TEXT,
  metadata JSONB,
  like_count INTEGER,
  comment_count INTEGER,
  user_has_liked BOOLEAN,
  created_at TIMESTAMPTZ
) AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  RETURN QUERY
  SELECT
    sp.id,
    sp.user_id,
    u.username,
    u.display_name,
    u.avatar_id,
    sp.post_type,
    sp.content,
    sp.breed_name,
    sp.photo_url,
    sp.metadata,
    sp.like_count,
    sp.comment_count,
    EXISTS(SELECT 1 FROM post_likes pl WHERE pl.post_id = sp.id AND pl.user_id = v_user_id) AS user_has_liked,
    sp.created_at
  FROM social_posts sp
  JOIN users u ON u.id = sp.user_id
  LEFT JOIN user_blocks ub ON ub.blocker_id = v_user_id AND ub.blocked_id = sp.user_id
  WHERE sp.is_public = true
    AND ub.id IS NULL
    AND (p_cursor IS NULL OR sp.created_at < p_cursor)
  ORDER BY sp.created_at DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Dogs Nearby: Find dogs within a radius
-- SUPA-001 (2026-05-10): dropped p_user_id — derives identity from
-- auth.uid() server-side so no client can impersonate another user.
-- ============================================================
CREATE OR REPLACE FUNCTION get_dogs_nearby(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_radius_miles DOUBLE PRECISION DEFAULT 5.0,
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  dog_id UUID,
  dog_name TEXT,
  breed TEXT,
  photo_url TEXT,
  owner_username TEXT,
  owner_display_name TEXT,
  distance_miles DOUBLE PRECISION
) AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;
  RETURN QUERY
  SELECT
    dp.id AS dog_id,
    dp.name AS dog_name,
    dp.breed,
    dp.photo_url,
    u.username AS owner_username,
    u.display_name AS owner_display_name,
    (
      3959 * acos(
        cos(radians(p_lat)) * cos(radians(u.approximate_lat))
        * cos(radians(u.approximate_lon) - radians(p_lon))
        + sin(radians(p_lat)) * sin(radians(u.approximate_lat))
      )
    ) AS distance_miles
  FROM dog_profiles dp
  JOIN users u ON u.id = dp.owner_id
  LEFT JOIN user_blocks ub ON (ub.blocker_id = v_user_id AND ub.blocked_id = dp.owner_id)
    OR (ub.blocker_id = dp.owner_id AND ub.blocked_id = v_user_id)
  WHERE u.location_sharing_enabled = true
    AND u.id != v_user_id
    AND ub.id IS NULL
    AND u.approximate_lat IS NOT NULL
    AND u.approximate_lon IS NOT NULL
    AND (
      3959 * acos(
        cos(radians(p_lat)) * cos(radians(u.approximate_lat))
        * cos(radians(u.approximate_lon) - radians(p_lon))
        + sin(radians(p_lat)) * sin(radians(u.approximate_lat))
      )
    ) <= p_radius_miles
  ORDER BY distance_miles ASC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Active Lost Dogs: Find lost dogs near a location
-- ============================================================
CREATE OR REPLACE FUNCTION get_active_lost_dogs(
  p_lat DOUBLE PRECISION,
  p_lon DOUBLE PRECISION,
  p_radius_miles DOUBLE PRECISION DEFAULT 10.0
)
RETURNS TABLE (
  id UUID,
  dog_name TEXT,
  breed TEXT,
  photo_url TEXT,
  description TEXT,
  last_seen_lat DOUBLE PRECISION,
  last_seen_lon DOUBLE PRECISION,
  last_seen_at TIMESTAMPTZ,
  distance_miles DOUBLE PRECISION,
  sighting_count BIGINT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ldr.id,
    ldr.dog_name,
    ldr.breed,
    ldr.photo_url,
    ldr.description,
    ldr.last_seen_lat,
    ldr.last_seen_lon,
    ldr.last_seen_at,
    (
      3959 * acos(
        cos(radians(p_lat)) * cos(radians(ldr.last_seen_lat))
        * cos(radians(ldr.last_seen_lon) - radians(p_lon))
        + sin(radians(p_lat)) * sin(radians(ldr.last_seen_lat))
      )
    ) AS distance_miles,
    (SELECT count(*) FROM lost_dog_sightings lds WHERE lds.report_id = ldr.id) AS sighting_count,
    ldr.created_at
  FROM lost_dog_reports ldr
  WHERE ldr.status = 'active'
    AND (
      3959 * acos(
        cos(radians(p_lat)) * cos(radians(ldr.last_seen_lat))
        * cos(radians(ldr.last_seen_lon) - radians(p_lon))
        + sin(radians(p_lat)) * sin(radians(ldr.last_seen_lat))
      )
    ) <= p_radius_miles
  ORDER BY ldr.created_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Sync sightings: Upsert from local Hive data
-- ============================================================
CREATE OR REPLACE FUNCTION sync_sightings(
  p_sightings JSONB
)
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER := 0;
  v_sighting JSONB;
BEGIN
  FOR v_sighting IN SELECT * FROM jsonb_array_elements(p_sightings)
  LOOP
    INSERT INTO sightings (
      user_id, breed_name, confidence, top3_breeds,
      latitude, longitude, location_accuracy,
      xp_earned, is_new_breed, rarity, local_id, created_at
    ) VALUES (
      auth.uid(),
      v_sighting->>'breed_name',
      (v_sighting->>'confidence')::DOUBLE PRECISION,
      v_sighting->'top3_breeds',
      (v_sighting->>'latitude')::DOUBLE PRECISION,
      (v_sighting->>'longitude')::DOUBLE PRECISION,
      (v_sighting->>'location_accuracy')::DOUBLE PRECISION,
      (v_sighting->>'xp_earned')::INTEGER,
      (v_sighting->>'is_new_breed')::BOOLEAN,
      v_sighting->>'rarity',
      v_sighting->>'local_id',
      (v_sighting->>'created_at')::TIMESTAMPTZ
    )
    ON CONFLICT (local_id) WHERE local_id IS NOT NULL
    DO NOTHING;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Leaderboard: Top users by XP
-- ============================================================
CREATE OR REPLACE FUNCTION get_leaderboard(
  p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
  rank BIGINT,
  user_id UUID,
  username TEXT,
  display_name TEXT,
  avatar_id TEXT,
  level INTEGER,
  total_xp INTEGER,
  kennel_count INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    ROW_NUMBER() OVER (ORDER BY u.total_xp DESC) AS rank,
    u.id AS user_id,
    u.username,
    u.display_name,
    u.avatar_id,
    u.level,
    u.total_xp,
    u.kennel_count
  FROM users u
  ORDER BY u.total_xp DESC
  LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
