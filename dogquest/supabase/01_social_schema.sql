-- ============================================================
-- DogQuest — Phase 1: Social Schema (TASK-013 + TASK-014 + TASK-015)
-- Run this in the Supabase SQL Editor.
-- Creates all remaining tables + indexes + enables RLS.
-- ============================================================

-- TASK-013: Social tables
-- ============================================================

CREATE TABLE social_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  post_type TEXT NOT NULL CHECK (post_type IN (
    'breed_discovered', 'achievement_unlocked', 'streak_milestone',
    'level_up', 'rare_find', 'set_completed', 'lost_dog_alert',
    'lost_dog_found', 'friendship_formed', 'photo_shared'
  )),
  content TEXT,
  breed_name TEXT,
  photo_url TEXT,
  metadata JSONB DEFAULT '{}',
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_social_posts_user ON social_posts(user_id);
CREATE INDEX idx_social_posts_type ON social_posts(post_type);
CREATE INDEX idx_social_posts_created ON social_posts(created_at DESC);

CREATE TABLE post_likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES social_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(post_id, user_id)
);

CREATE TABLE post_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES social_posts(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_post_comments_post ON post_comments(post_id);

CREATE TABLE follows (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  following_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(follower_id, following_id)
);

CREATE INDEX idx_follows_follower ON follows(follower_id);
CREATE INDEX idx_follows_following ON follows(following_id);

CREATE TABLE user_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  blocker_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  blocked_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(blocker_id, blocked_id)
);

CREATE TABLE content_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content_type TEXT NOT NULL CHECK (content_type IN ('social_post', 'comment', 'dog_profile', 'community_post')),
  content_id UUID NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN ('spam', 'harassment', 'inappropriate', 'misinformation', 'other')),
  description TEXT,
  status TEXT NOT NULL CHECK (status IN ('pending', 'reviewed', 'actioned', 'dismissed')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- TASK-014: Friendship and pack tables
-- ============================================================

CREATE TABLE friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_dog_id UUID REFERENCES dog_profiles(id) ON DELETE CASCADE NOT NULL,
  requester_dog_owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  recipient_dog_id UUID REFERENCES dog_profiles(id) ON DELETE CASCADE NOT NULL,
  recipient_dog_owner_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'accepted', 'rejected')) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  UNIQUE(requester_dog_id, recipient_dog_id)
);

CREATE INDEX idx_friendships_requester ON friendships(requester_dog_owner_id);
CREATE INDEX idx_friendships_recipient ON friendships(recipient_dog_owner_id);
CREATE INDEX idx_friendships_status ON friendships(status);

CREATE TABLE packs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  invite_code TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE pack_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id UUID REFERENCES packs(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'member')) DEFAULT 'member',
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(pack_id, user_id)
);

CREATE TABLE pack_dogs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pack_id UUID REFERENCES packs(id) ON DELETE CASCADE NOT NULL,
  dog_id UUID REFERENCES dog_profiles(id) ON DELETE CASCADE NOT NULL,
  UNIQUE(pack_id, dog_id)
);

-- TASK-015: Lost dog and community tables
-- ============================================================

CREATE TABLE lost_dog_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  dog_profile_id UUID REFERENCES dog_profiles(id) ON DELETE SET NULL,
  dog_name TEXT NOT NULL,
  breed TEXT NOT NULL,
  photo_url TEXT,
  description TEXT,
  last_seen_lat DOUBLE PRECISION NOT NULL,
  last_seen_lon DOUBLE PRECISION NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL,
  contact_info TEXT,
  status TEXT NOT NULL CHECK (status IN ('active', 'found', 'cancelled')) DEFAULT 'active',
  alert_radius_miles DOUBLE PRECISION DEFAULT 5.0,
  created_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_lost_dog_reports_status ON lost_dog_reports(status) WHERE status = 'active';

CREATE TABLE lost_dog_sightings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID REFERENCES lost_dog_reports(id) ON DELETE CASCADE NOT NULL,
  reporter_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_lost_dog_sightings_report ON lost_dog_sightings(report_id);

CREATE TABLE breed_communities (
  breed_name TEXT PRIMARY KEY,
  member_count INTEGER DEFAULT 0,
  post_count INTEGER DEFAULT 0,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE breed_community_memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  breed_name TEXT REFERENCES breed_communities(breed_name) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(breed_name, user_id)
);

CREATE TABLE breed_community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  breed_name TEXT REFERENCES breed_communities(breed_name) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  content TEXT NOT NULL,
  photo_url TEXT,
  like_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_breed_community_posts_breed ON breed_community_posts(breed_name);

CREATE TABLE playdates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  organizer_dog_id UUID REFERENCES dog_profiles(id) ON DELETE CASCADE NOT NULL,
  location_name TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  max_dogs INTEGER DEFAULT 5,
  description TEXT,
  status TEXT NOT NULL CHECK (status IN ('upcoming', 'ongoing', 'completed', 'cancelled')) DEFAULT 'upcoming',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_playdates_scheduled ON playdates(scheduled_at) WHERE status = 'upcoming';

CREATE TABLE playdate_rsvps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  playdate_id UUID REFERENCES playdates(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  dog_id UUID REFERENCES dog_profiles(id) ON DELETE CASCADE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('going', 'maybe', 'declined')) DEFAULT 'going',
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(playdate_id, dog_id)
);

-- Enable RLS on all tables
-- ============================================================

ALTER TABLE social_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE content_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE packs ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE pack_dogs ENABLE ROW LEVEL SECURITY;
ALTER TABLE lost_dog_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE lost_dog_sightings ENABLE ROW LEVEL SECURITY;
ALTER TABLE breed_communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE breed_community_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE breed_community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdates ENABLE ROW LEVEL SECURITY;
ALTER TABLE playdate_rsvps ENABLE ROW LEVEL SECURITY;
