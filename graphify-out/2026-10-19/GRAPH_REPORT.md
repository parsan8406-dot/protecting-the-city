# Graph Report - gun-game  (2026-10-19)

## Corpus Check
- 130 files · ~370,388 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1627 nodes · 5393 edges · 84 communities (69 shown, 15 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 1370 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- rulesForMode
- admin_auth.go
- withDB
- PlayerModel
- jsonResponse
- pathArena
- build_arena.py
- Hub
- checkAndUnlockAchievements
- handlers_auth.go
- matchmaking.go
- demon_test.go
- Player
- RoundState
- adRewardClaimHandler
- net/http.ResponseWriter
- models.go
- patch_scenes.py
- NewHub
- StoreBillingPlugin
- context.Context
- testing.T
- db.go
- handlers_clan.go
- build_rig.py
- org.godotengine.godot.plugin.UsedByGodot
- time.Time
- seasonCupDefs
- Row Sheet UI Asset Preview Page
- Arena
- mustArena
- applyLoadout
- weekly_rewards.go
- abilities_test.go
- .FindPath
- bombHub
- resetMM
- MessageModel
- BillingProxyActivity
- android.os.Bundle
- android.content.Intent
- BazaarBillingPlugin
- MyketBillingPlugin
- normalize_skin.py
- angleDiff
- deform_check.py
- countOf
- getPlayerByID
- make_wind_swirls.py
- missions.go
- col
- claimSeasonCupHandler
- dependencies
- arm_angles.py
- solve
- Hub
- parseWSMessage
- prepare_chat_emojis.py
- check_store_apk.sh
- Mode
- PlayerStats
- strip_white_bg.py
- sweep_sniper.py
- layout_check.py
- scan_arms.py
- iap_billing/build.sh
- rewarded_ads/build.sh
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- make_leaf_textures.py
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- broadcastChatMessage
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- gun_game_server
- redeemGiftCodeHandler

## God Nodes (most connected - your core abstractions)
1. `col()` - 185 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `Hub` - 62 edges
6. `PlayerModel` - 61 edges
7. `NewHub()` - 56 edges
8. `getPlayerByUsername()` - 54 edges
9. `h()` - 48 edges
10. `Player` - 46 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `spawnShieldFor()` --calls--> `ModeOfMatch()`  [INFERRED]
  gun_game_server/match_round.go → gun_game_server/mm_backfill.go
- `TestGuardBlocksShotsAndBombs()` --calls--> `isGuarded()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `TestSegmentHitsCircle()` --calls--> `segmentHitsCircle()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `TestLaserPiercesBodiesAndDealsSixtyPercent()` --calls--> `laserTickDamage()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (84 total, 15 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "rulesForMode"
Cohesion: 0.24
Nodes (8): Arena, gentleBotLoadout(), TestEasyBotsCarryNoSnipersOrLegends(), TestDemonHuntRules(), rulesForMode(), spawnShieldFor(), TestRevengeRules(), RoundRules

### Community 2 - "admin_auth.go"
Cohesion: 0.06
Nodes (57): net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders(), checkAdminLogin() (+49 more)

### Community 3 - "withDB"
Cohesion: 0.06
Nodes (68): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+60 more)

### Community 4 - "PlayerModel"
Cohesion: 0.18
Nodes (22): MaxLevelOf(), PlayerModel, RecentMatch, SkinDef, SkinEquipRequest, activeSkin(), allCharacterIDs(), characterLevel() (+14 more)

### Community 5 - "jsonResponse"
Cohesion: 0.15
Nodes (45): newID(), clanMemberRole(), getClanRequestsHandler(), joinClanHandler(), kickClanMemberHandler(), leaveClanHandler(), promoteSuccessor(), requireClanAuthority() (+37 more)

### Community 6 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "Hub"
Cohesion: 0.11
Nodes (16): github.com/gorilla/websocket.Conn, time.Duration, Client, SetPlayerOnline(), allowPaced(), equippedFor(), BotRuntime, Hub (+8 more)

### Community 9 - "checkAndUnlockAchievements"
Cohesion: 0.36
Nodes (8): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement(), persistProfileStats(), TestNextAchievementPicksClosestLocked(), UnlockedAchievement

### Community 10 - "handlers_auth.go"
Cohesion: 0.07
Nodes (54): bufio.Scanner, guardStatus(), seedAuthPlayer(), TestProfileStatsFromRound(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane() (+46 more)

### Community 11 - "matchmaking.go"
Cohesion: 0.10
Nodes (43): math/rand.Rand, botSkillFor(), keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots() (+35 more)

### Community 12 - "demon_test.go"
Cohesion: 0.19
Nodes (17): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+9 more)

### Community 13 - "Player"
Cohesion: 0.15
Nodes (15): laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), BotRuntime, Hub (+7 more)

### Community 14 - "RoundState"
Cohesion: 0.22
Nodes (6): Arena, BotRuntime, Hub, newDemon(), DemonState, RoundState

### Community 15 - "adRewardClaimHandler"
Cohesion: 0.52
Nodes (6): adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adRewardStatusHandler(), adTokenRewarded()

### Community 16 - "net/http.ResponseWriter"
Cohesion: 0.13
Nodes (59): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler() (+51 more)

### Community 17 - "models.go"
Cohesion: 0.08
Nodes (30): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+22 more)

### Community 18 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 19 - "NewHub"
Cohesion: 0.08
Nodes (51): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), Arena, TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager() (+43 more)

### Community 20 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 21 - "context.Context"
Cohesion: 0.16
Nodes (30): context.Context, adminClanHandler(), adminGiftCodeRedemptionsHandler(), adminFindPlayer(), adminPlayerHandler(), findAll(), nonNilMatches(), ChatMessageModel (+22 more)

### Community 22 - "testing.T"
Cohesion: 0.10
Nodes (41): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks() (+33 more)

### Community 23 - "db.go"
Cohesion: 0.15
Nodes (19): go.mongodb.org/mongo-driver/mongo.IndexModel, seedAchievements(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+11 more)

### Community 24 - "handlers_clan.go"
Cohesion: 0.13
Nodes (30): adminClansHandler(), cityPointsRow, ClanModel, clanLeaderInfo(), clanRowLess(), clanSummary(), clanWorldRank(), createClanHandler() (+22 more)

### Community 25 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 26 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 27 - "time.Time"
Cohesion: 0.15
Nodes (13): sync.Mutex, time.Time, abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage() (+5 more)

### Community 28 - "seasonCupDefs"
Cohesion: 0.20
Nodes (20): seasonCupCount(), PlayerSeasonCups, currentSeasonCups(), defaultSeasonCups(), fallbackSeasonCups(), invalidateSeasonCupCache(), seasonCupDefs(), seasonCupID() (+12 more)

### Community 29 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 30 - "Arena"
Cohesion: 0.17
Nodes (6): clampF(), Arena, arenaFile, Room, Arena, hashString()

### Community 31 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 32 - "applyLoadout"
Cohesion: 0.07
Nodes (52): TestBombStockIsThreePerMatch(), TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor() (+44 more)

### Community 33 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 34 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 35 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 36 - "bombHub"
Cohesion: 0.47
Nodes (8): addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput(), TestBombZeroDirectionThrowsForward()

### Community 37 - "resetMM"
Cohesion: 0.39
Nodes (11): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), busyNamesLocked(), ReleaseMatch(), sweepStaleMatchesLocked(), resetMM(), seedMatch() (+3 more)

### Community 38 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 39 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 40 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 41 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 44 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 45 - "angleDiff"
Cohesion: 0.39
Nodes (10): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), angleDiff(), clampRotation() (+2 more)

### Community 46 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 47 - "countOf"
Cohesion: 0.22
Nodes (17): go.mongodb.org/mongo-driver/bson.M, fanOutMessage(), adminShopHandler(), adminAuditHandler(), adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), countOf() (+9 more)

### Community 48 - "getPlayerByID"
Cohesion: 0.19
Nodes (19): resolvePlayers(), DailyBonusClaimBody, buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler(), claimSeasonChallengeHandler(), claimSeasonPassHandler(), getDailyMissionsHandler() (+11 more)

### Community 49 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 50 - "missions.go"
Cohesion: 0.06
Nodes (63): DailyBonusTier, DailyMissionDef, DailyMissionDoc, buildMissionsResponse(), buildSeasonPassResponse(), minInt(), LiveObjective, buildObjectives() (+55 more)

### Community 51 - "col"
Cohesion: 0.15
Nodes (23): go.mongodb.org/mongo-driver/mongo.Collection, engageLockdown(), col(), googleResult, applyGoogleIdentity(), claimFirstSession(), googleAuthCallbackHandler(), googleFail() (+15 more)

### Community 52 - "claimSeasonCupHandler"
Cohesion: 0.53
Nodes (5): buildSeasonCupsResponse(), claimSeasonCupHandler(), getSeasonCupsHandler(), seasonXPOf(), SeasonCupClaimBody

### Community 53 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 54 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 55 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 56 - "Hub"
Cohesion: 0.16
Nodes (6): BotSeat, Hub, botsInMatchOf(), MatchOf(), ModeOfMatch(), TeamOf()

### Community 57 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 58 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 59 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 60 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 62 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 63 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 78 - "broadcastChatMessage"
Cohesion: 0.40
Nodes (5): broadcastChatMessage(), NotifyEveryone(), NotifyUsers(), queueNotify(), userMessage

### Community 94 - "redeemGiftCodeHandler"
Cohesion: 0.39
Nodes (8): createGiftCodeRequest, GiftCode, createGiftCode(), createGiftCodeHandler(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeHandler(), redeemGiftCodeRequest

## Knowledge Gaps
- **71 isolated node(s):** `build.sh script`, `NONE`, `SERVICE`, `BROADCAST`, `build.sh script` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `admin_auth.go`, `withDB`, `PlayerModel`, `jsonResponse`, `Hub`, `checkAndUnlockAchievements`, `handlers_auth.go`, `matchmaking.go`, `adRewardClaimHandler`, `net/http.ResponseWriter`, `context.Context`, `db.go`, `handlers_clan.go`, `seasonCupDefs`, `applyLoadout`, `weekly_rewards.go`, `countOf`, `getPlayerByID`, `missions.go`, `claimSeasonCupHandler`, `redeemGiftCodeHandler`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `applyLoadout`, `jsonResponse`, `Player`, `angleDiff`, `broadcastChatMessage`, `RoundState`, `NewHub`, `parseWSMessage`, `time.Time`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `withDB`, `jsonResponse`, `checkAndUnlockAchievements`, `handlers_auth.go`, `matchmaking.go`, `adRewardClaimHandler`, `net/http.ResponseWriter`, `models.go`, `context.Context`, `handlers_clan.go`, `time.Time`, `seasonCupDefs`, `MessageModel`, `getPlayerByID`, `missions.go`, `col`, `claimSeasonCupHandler`, `PlayerStats`, `broadcastChatMessage`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Are the 175 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 175 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `NONE`, `SERVICE` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._