/// Achievement definitions shared across UI and service layer.
///
/// Each entry: key → (emoji, title, description).
const achievements = {
  // ─── Collection Milestones ───────────────────────────────────────────
  'first_dog': ('🐾', 'First Paw Print', 'Identify your first dog'),
  'five_species': ('🌿', 'Dog Curious', 'Collect 5 different species'),
  'ten_species': ('🏆', 'Pack Explorer', 'Collect 10 different species'),
  'twenty_species': ('🐕', 'Breed Spotter', 'Collect 20 different species'),
  'fifty_species': ('🌎', 'Globe Trotter', 'Collect 50 different species'),
  'hundred_species': ('💯', 'Centurion', 'Collect 100 different species'),
  'two_hundred_species': ('🏅', 'Kennel Master', 'Collect 200 species'),
  'all_common': ('📋', 'Common Complete', 'Collect every Common breed'),
  'all_uncommon': ('📗', 'Uncommon Complete', 'Collect every Uncommon breed'),
  'all_rare': ('📘', 'Rare Complete', 'Collect every Rare breed'),

  // ─── Rarity Finds ───────────────────────────────────────────────────
  'rare_find': ('💎', 'Rare Encounter', 'Identify a rare dog'),
  'legendary_find': ('✨', 'Legend Spotter', 'Identify a legendary dog'),
  'five_rare': ('💠', 'Gem Hunter', 'Collect 5 rare breeds'),
  'five_legendary': ('👑', 'Crown Collector', 'Collect 5 legendary breeds'),

  // ─── Rarity Badge Achievements ────────────────────────────────────
  'first_uncommon': ('🟤', 'Uncommon Find', 'Spot your first Uncommon breed'),
  'first_rare': ('🔵', 'Rare Encounter', 'Spot your first Rare breed'),
  'first_epic': ('🟣', 'Epic Discovery', 'Spot your first Epic breed'),
  'ten_uncommon': (
    '📦',
    'Uncommon Collector',
    'Spot 10 different Uncommon breeds'
  ),
  'ten_rare': ('💠', 'Rare Collector', 'Spot 10 different Rare breeds'),

  // ─── Levelling ──────────────────────────────────────────────────────
  'level_5': ('⭐', 'Rising Doger', 'Reach level 5'),
  'level_10': ('🌟', 'Expert Trainer', 'Reach level 10'),
  'level_20': ('🌠', 'Alpha Dog', 'Reach level 20'),
  'level_30': ('🔱', 'Elite Handler', 'Reach level 30'),

  // ─── Streaks ────────────────────────────────────────────────────────
  'streak_3': ('🔥', 'Getting Warmed Up', 'Maintain a 3-day streak'),
  'streak_7': ('🔥', 'Week Warrior', 'Maintain a 7-day streak'),
  'streak_30': ('💪', 'Dedicated Doger', 'Maintain a 30-day streak'),

  // ─── Conservation ───────────────────────────────────────────────────
  'endangered_spotter': ('🛡️', 'Guardian', 'Identify an endangered dog'),
  'conservation_hero': (
    '🌱',
    'Conservation Hero',
    'Collect 5 threatened species'
  ),

  // ─── Quiz ─────────────────────────────────────────────────────────
  'first_quiz': ('📝', 'Quiz Taker', 'Complete your first quiz'),
  'ten_quizzes': ('🎓', 'Scholar', 'Complete 10 quizzes'),
  'perfect_quiz': ('💯', 'Perfect Score', 'Get 10/10 on a quiz'),
  'five_perfect': ('🧠', 'Cynology PhD', 'Get 5 perfect quiz scores'),
};
