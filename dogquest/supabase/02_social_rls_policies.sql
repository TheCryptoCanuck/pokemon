-- ============================================================
-- DogQuest — Phase 1: RLS Policies for Social Tables (TASK-016)
-- Run this in the Supabase SQL Editor AFTER 01_social_schema.sql.
-- ============================================================

-- SOCIAL POSTS: anyone can read public posts; owners can CRUD their own
CREATE POLICY "social_posts_read" ON social_posts
  FOR SELECT USING (is_public = true OR user_id = auth.uid());

CREATE POLICY "social_posts_insert" ON social_posts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "social_posts_update" ON social_posts
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "social_posts_delete" ON social_posts
  FOR DELETE USING (user_id = auth.uid());

-- POST LIKES: anyone can read; users can like/unlike
CREATE POLICY "post_likes_read" ON post_likes
  FOR SELECT USING (true);

CREATE POLICY "post_likes_insert" ON post_likes
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "post_likes_delete" ON post_likes
  FOR DELETE USING (user_id = auth.uid());

-- POST COMMENTS: anyone can read; users can CRUD their own
CREATE POLICY "post_comments_read" ON post_comments
  FOR SELECT USING (true);

CREATE POLICY "post_comments_insert" ON post_comments
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "post_comments_update" ON post_comments
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "post_comments_delete" ON post_comments
  FOR DELETE USING (user_id = auth.uid());

-- FOLLOWS: anyone can read; users manage their own follows
CREATE POLICY "follows_read" ON follows
  FOR SELECT USING (true);

CREATE POLICY "follows_insert" ON follows
  FOR INSERT WITH CHECK (follower_id = auth.uid());

CREATE POLICY "follows_delete" ON follows
  FOR DELETE USING (follower_id = auth.uid());

-- USER BLOCKS: only the blocker can see/manage their blocks
CREATE POLICY "user_blocks_own" ON user_blocks
  FOR SELECT USING (blocker_id = auth.uid());

CREATE POLICY "user_blocks_insert" ON user_blocks
  FOR INSERT WITH CHECK (blocker_id = auth.uid());

CREATE POLICY "user_blocks_delete" ON user_blocks
  FOR DELETE USING (blocker_id = auth.uid());

-- CONTENT REPORTS: reporters can see their own; insert allowed for any authenticated user
CREATE POLICY "content_reports_read" ON content_reports
  FOR SELECT USING (reporter_id = auth.uid());

CREATE POLICY "content_reports_insert" ON content_reports
  FOR INSERT WITH CHECK (reporter_id = auth.uid());

-- FRIENDSHIPS: both parties can read; requester's owner can insert; either owner can update
CREATE POLICY "friendships_read" ON friendships
  FOR SELECT USING (
    requester_dog_owner_id = auth.uid() OR recipient_dog_owner_id = auth.uid()
  );

CREATE POLICY "friendships_insert" ON friendships
  FOR INSERT WITH CHECK (requester_dog_owner_id = auth.uid());

CREATE POLICY "friendships_update" ON friendships
  FOR UPDATE USING (
    requester_dog_owner_id = auth.uid() OR recipient_dog_owner_id = auth.uid()
  );

CREATE POLICY "friendships_delete" ON friendships
  FOR DELETE USING (
    requester_dog_owner_id = auth.uid() OR recipient_dog_owner_id = auth.uid()
  );

-- PACKS: members can read; creator can manage
CREATE POLICY "packs_read" ON packs
  FOR SELECT USING (
    id IN (SELECT pack_id FROM pack_members WHERE user_id = auth.uid())
  );

CREATE POLICY "packs_insert" ON packs
  FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "packs_update" ON packs
  FOR UPDATE USING (created_by = auth.uid());

CREATE POLICY "packs_delete" ON packs
  FOR DELETE USING (created_by = auth.uid());

-- PACK MEMBERS: members can read pack membership; pack owner can manage
CREATE POLICY "pack_members_read" ON pack_members
  FOR SELECT USING (
    pack_id IN (SELECT pack_id FROM pack_members pm WHERE pm.user_id = auth.uid())
  );

CREATE POLICY "pack_members_insert" ON pack_members
  FOR INSERT WITH CHECK (
    user_id = auth.uid()
    OR pack_id IN (SELECT id FROM packs WHERE created_by = auth.uid())
  );

CREATE POLICY "pack_members_delete" ON pack_members
  FOR DELETE USING (
    user_id = auth.uid()
    OR pack_id IN (SELECT id FROM packs WHERE created_by = auth.uid())
  );

-- PACK DOGS: members can read; dog owner or pack owner can manage
CREATE POLICY "pack_dogs_read" ON pack_dogs
  FOR SELECT USING (
    pack_id IN (SELECT pack_id FROM pack_members WHERE user_id = auth.uid())
  );

CREATE POLICY "pack_dogs_insert" ON pack_dogs
  FOR INSERT WITH CHECK (
    dog_id IN (SELECT id FROM dog_profiles WHERE owner_id = auth.uid())
    OR pack_id IN (SELECT id FROM packs WHERE created_by = auth.uid())
  );

CREATE POLICY "pack_dogs_delete" ON pack_dogs
  FOR DELETE USING (
    dog_id IN (SELECT id FROM dog_profiles WHERE owner_id = auth.uid())
    OR pack_id IN (SELECT id FROM packs WHERE created_by = auth.uid())
  );

-- LOST DOG REPORTS: anyone can read active reports; owner can CRUD
CREATE POLICY "lost_dog_reports_read" ON lost_dog_reports
  FOR SELECT USING (status = 'active' OR user_id = auth.uid());

CREATE POLICY "lost_dog_reports_insert" ON lost_dog_reports
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "lost_dog_reports_update" ON lost_dog_reports
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "lost_dog_reports_delete" ON lost_dog_reports
  FOR DELETE USING (user_id = auth.uid());

-- LOST DOG SIGHTINGS: anyone can read; authenticated users can report
CREATE POLICY "lost_dog_sightings_read" ON lost_dog_sightings
  FOR SELECT USING (true);

CREATE POLICY "lost_dog_sightings_insert" ON lost_dog_sightings
  FOR INSERT WITH CHECK (reporter_id = auth.uid());

-- BREED COMMUNITIES: anyone can read
CREATE POLICY "breed_communities_read" ON breed_communities
  FOR SELECT USING (true);

-- BREED COMMUNITY MEMBERSHIPS: anyone can read; users manage their own
CREATE POLICY "breed_community_memberships_read" ON breed_community_memberships
  FOR SELECT USING (true);

CREATE POLICY "breed_community_memberships_insert" ON breed_community_memberships
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "breed_community_memberships_delete" ON breed_community_memberships
  FOR DELETE USING (user_id = auth.uid());

-- BREED COMMUNITY POSTS: anyone can read; users manage their own
CREATE POLICY "breed_community_posts_read" ON breed_community_posts
  FOR SELECT USING (true);

CREATE POLICY "breed_community_posts_insert" ON breed_community_posts
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "breed_community_posts_update" ON breed_community_posts
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "breed_community_posts_delete" ON breed_community_posts
  FOR DELETE USING (user_id = auth.uid());

-- PLAYDATES: anyone can read upcoming; organizer can manage
CREATE POLICY "playdates_read" ON playdates
  FOR SELECT USING (status = 'upcoming' OR organizer_id = auth.uid());

CREATE POLICY "playdates_insert" ON playdates
  FOR INSERT WITH CHECK (organizer_id = auth.uid());

CREATE POLICY "playdates_update" ON playdates
  FOR UPDATE USING (organizer_id = auth.uid());

CREATE POLICY "playdates_delete" ON playdates
  FOR DELETE USING (organizer_id = auth.uid());

-- PLAYDATE RSVPS: anyone can read; users manage their own
CREATE POLICY "playdate_rsvps_read" ON playdate_rsvps
  FOR SELECT USING (true);

CREATE POLICY "playdate_rsvps_insert" ON playdate_rsvps
  FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "playdate_rsvps_update" ON playdate_rsvps
  FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "playdate_rsvps_delete" ON playdate_rsvps
  FOR DELETE USING (user_id = auth.uid());
