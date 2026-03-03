/// Achievement definitions shared across UI and service layer.
///
/// Each entry: key → (emoji, title, description).
const achievements = {
  // ─── Collection Milestones ───────────────────────────────────────────
  'first_bird': ('🐦', 'First Feather', 'Identify your first bird'),
  'five_species': ('🌿', 'Nature Curious', 'Collect 5 different species'),
  'ten_species': ('🏆', 'Avid Birder', 'Collect 10 different species'),
  'twenty_species': ('🦅', 'Wing Watcher', 'Collect 20 different species'),
  'fifty_species': ('🌎', 'Globe Trotter', 'Collect 50 different species'),
  'hundred_species': ('💯', 'Centurion', 'Collect 100 different species'),
  'two_hundred_species': ('🏅', 'Binocular Master', 'Collect 200 species'),
  'all_common': ('📋', 'Common Catalogue', 'Collect every common bird'),
  'all_uncommon': ('📗', 'Uncommon Collector', 'Collect every uncommon bird'),

  // ─── Rarity Finds ───────────────────────────────────────────────────
  'rare_find': ('💎', 'Rare Encounter', 'Identify a rare bird'),
  'legendary_find': ('✨', 'Legend Spotter', 'Identify a legendary bird'),
  'five_rare': ('💠', 'Gem Hunter', 'Collect 5 rare birds'),
  'five_legendary': ('👑', 'Crown Collector', 'Collect 5 legendary birds'),

  // ─── Levelling ──────────────────────────────────────────────────────
  'level_5': ('⭐', 'Rising Birder', 'Reach level 5'),
  'level_10': ('🌟', 'Expert Nester', 'Reach level 10'),
  'level_20': ('🌠', 'Sky Master', 'Reach level 20'),
  'level_30': ('🔱', 'Falconer Elite', 'Reach level 30'),

  // ─── Streaks ────────────────────────────────────────────────────────
  'streak_3': ('🔥', 'Getting Warmed Up', 'Maintain a 3-day streak'),
  'streak_7': ('🔥', 'Week Warrior', 'Maintain a 7-day streak'),
  'streak_30': ('💪', 'Dedicated Birder', 'Maintain a 30-day streak'),

  // ─── Conservation ───────────────────────────────────────────────────
  'endangered_spotter': ('🛡️', 'Guardian', 'Identify an endangered bird'),
  'conservation_hero': ('🌱', 'Conservation Hero', 'Collect 5 threatened species'),

  // ─── Quiz ─────────────────────────────────────────────────────────
  'first_quiz': ('📝', 'Quiz Taker', 'Complete your first quiz'),
  'ten_quizzes': ('🎓', 'Scholar', 'Complete 10 quizzes'),
  'perfect_quiz': ('💯', 'Perfect Score', 'Get 10/10 on a quiz'),
  'five_perfect': ('🧠', 'Ornithology PhD', 'Get 5 perfect quiz scores'),
};
