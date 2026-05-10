@echo off
cd /d C:\Users\Administrator\AviQuest-\dogquest
set LOG=scripts\commit_refactor.log

echo --- start --- > %LOG%
git log --oneline -n 3 >> %LOG% 2>&1
echo --- status pre --- >> %LOG%
git status --short >> %LOG% 2>&1

echo --- commit 1: new widget files (lib/widgets/{identify,lost_dog,map,pack,profile}/) --- >> %LOG%
git add lib\widgets\identify\ lib\widgets\lost_dog\bottom_sheet_action.dart lib\widgets\lost_dog\help_find_tab.dart lib\widgets\lost_dog\lost_dog_map_view.dart lib\widgets\lost_dog\lost_dog_report_card.dart lib\widgets\lost_dog\missing_dogs_tab.dart lib\widgets\lost_dog\remote_lost_dog_card.dart lib\widgets\lost_dog\stats_dashboard.dart lib\widgets\map\breed_location_stat.dart lib\widgets\map\dog_detail_card.dart lib\widgets\map\dog_selection_prompt.dart lib\widgets\map\friends_list.dart lib\widgets\map\friendship_stats_bar.dart lib\widgets\map\live_map_filter_chip.dart lib\widgets\map\neighborhood_empty_state.dart lib\widgets\map\neighborhood_grid.dart lib\widgets\map\sighting_stat_bubble.dart lib\widgets\map\tab_button.dart lib\widgets\pack\ lib\widgets\profile\ >> %LOG% 2>&1
git commit -m "Extract god-class screens into widget subfolders (refactor pass 1/4)" >> %LOG% 2>&1

echo --- commit 2: lost_dog_hub_screen dead-code purge + screen rewires --- >> %LOG%
git add lib\screens\lost_dog_hub_screen.dart lib\screens\pack_screen.dart >> %LOG% 2>&1
git commit -m "Wire god-class screens to extracted widgets; purge 1538 lines of dead duplicate classes from lost_dog_hub_screen (refactor pass 2/4)" >> %LOG% 2>&1

echo --- commit 3: pre-existing main.dart + service fixes (piggybacked) --- >> %LOG%
git add lib\main.dart lib\services\sighting_sync_service.dart lib\screens\dogs_nearby_screen.dart lib\widgets\dogquest_banner_ad.dart >> %LOG% 2>&1
git commit -m "Fix pre-existing API drift: BreedCollectionService arg swap, BackendSyncService api param, breedCollectionServiceProvider rename, getCurrentLocation->getLocation, hasAdConsent->hasConsented, connectivity_plus import (refactor pass 3/4)" >> %LOG% 2>&1

echo --- commit 4: friends_screen + format pass on entire tree --- >> %LOG%
git add lib\screens\friends_screen.dart >> %LOG% 2>&1
git commit -m "Drop broken Supabase sendRequest path (architecture mismatch); FriendshipRemote conversion in watchPendingRequests (refactor pass 4/4)" >> %LOG% 2>&1

echo --- commit 5: dart format pass (180 files) --- >> %LOG%
git add -u lib\ test\ >> %LOG% 2>&1
git commit -m "Apply dart format across 180 files (post-refactor format hygiene)" >> %LOG% 2>&1

echo --- final log --- >> %LOG%
git log --oneline -n 8 >> %LOG% 2>&1
echo --- status post --- >> %LOG%
git status --short >> %LOG% 2>&1
echo --- end --- >> %LOG%
