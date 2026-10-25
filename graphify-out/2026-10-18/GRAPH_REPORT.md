# Graph Report - gun-game  (2026-10-18)

## Corpus Check
- 130 files · ~368,226 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1611 nodes · 5335 edges · 82 communities (68 shown, 14 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 1352 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- missions_test.go
- admin_auth.go
- withDB
- skins.go
- col
- testing.T
- build_arena.py
- Hub
- NewHub
- handlers_auth.go
- matchmaking.go
- demon_test.go
- statsOf
- RoundState
- time.Time
- PlayerModel
- models.go
- patch_scenes.py
- LoadArena
- StoreBillingPlugin
- handlers_chat.go
- bot_sense_test.go
- context.Context
- handlers_leaderboard.go
- build_rig.py
- org.godotengine.godot.plugin.UsedByGodot
- Player
- seasonCupDefs
- Row Sheet UI Asset Preview Page
- Arena
- mustArena
- WeaponStatsFor
- weekly_rewards.go
- abilities_test.go
- .FindPath
- applyLoadout
- mm_backfill.go
- distance
- android.content.Intent
- android.os.Bundle
- game_modes.go
- BazaarBillingPlugin
- MyketBillingPlugin
- normalize_skin.py
- .getPluginSignals
- deform_check.py
- MessageModel
- make_wind_swirls.py
- missions.go
- dependencies
- arm_angles.py
- solve
- time.Duration
- parseWSMessage
- prepare_chat_emojis.py
- check_store_apk.sh
- Mode
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
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- gun_game_server
- Hub
- handlers_gift_codes.go
- SeedCurrencyPacks
- applyMatchToSeasonStats

## God Nodes (most connected - your core abstractions)
1. `col()` - 185 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `Hub` - 62 edges
6. `PlayerModel` - 61 edges
7. `NewHub()` - 54 edges
8. `getPlayerByUsername()` - 53 edges
9. `h()` - 48 edges
10. `Player` - 46 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `TestGuardBlocksShotsAndBombs()` --calls--> `isGuarded()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `laserSegment()` --calls--> `arenaOf()`  [INFERRED]
  gun_game_server/abilities.go → gun_game_server/arena.go
- `TestLaserPiercesBodiesAndDealsSixtyPercent()` --calls--> `laserTickDamage()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `abilityPlayer()` --calls--> `applyLoadout()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/hub.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (82 total, 14 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "missions_test.go"
Cohesion: 0.13
Nodes (21): DailyBonusTier, buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), dailyBonusTierByNeed(), missionDayEnd(), missionSecondsLeft(), missionSeed() (+13 more)

### Community 2 - "admin_auth.go"
Cohesion: 0.06
Nodes (62): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminLogoutHandler(), adminMePayload(), adminPanelEnabled() (+54 more)

### Community 3 - "withDB"
Cohesion: 0.08
Nodes (52): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull() (+44 more)

### Community 4 - "skins.go"
Cohesion: 0.12
Nodes (29): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+21 more)

### Community 5 - "col"
Cohesion: 0.06
Nodes (185): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/bson.M, go.mongodb.org/mongo-driver/mongo.Collection, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom() (+177 more)

### Community 6 - "testing.T"
Cohesion: 0.09
Nodes (36): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget() (+28 more)

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "Hub"
Cohesion: 0.10
Nodes (19): github.com/gorilla/websocket.Conn, refreshAbilityTimers(), Client, SetPlayerOnline(), equippedFor(), BotRuntime, Hub, Hub (+11 more)

### Community 9 - "NewHub"
Cohesion: 0.17
Nodes (25): TestDemonHuntRules(), NewHub(), rulesForMode(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly() (+17 more)

### Community 10 - "handlers_auth.go"
Cohesion: 0.07
Nodes (65): nextAchievement(), guardStatus(), seedAuthPlayer(), TestProfileStatsFromRound(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody() (+57 more)

### Community 11 - "matchmaking.go"
Cohesion: 0.11
Nodes (40): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), gameModeByID() (+32 more)

### Community 12 - "demon_test.go"
Cohesion: 0.20
Nodes (17): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+9 more)

### Community 13 - "statsOf"
Cohesion: 0.16
Nodes (17): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), BotRuntime, Hub (+9 more)

### Community 14 - "RoundState"
Cohesion: 0.14
Nodes (6): Arena, Hub, newDemon(), DemonState, Hub, RoundState

### Community 15 - "time.Time"
Cohesion: 0.16
Nodes (17): sync.Mutex, time.Time, AdminAuditEntry, adRewardDay, adRewardRequest, DailyMissionDoc, giftFailLimiter, GoogleAuthPending (+9 more)

### Community 16 - "PlayerModel"
Cohesion: 0.23
Nodes (13): AchievementDef, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), TestAchievementCatalogIsSane(), buildSeasonCupsResponse(), seasonXPOf() (+5 more)

### Community 17 - "models.go"
Cohesion: 0.07
Nodes (32): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanJoinRequestModel, ClanMember (+24 more)

### Community 18 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 19 - "LoadArena"
Cohesion: 0.12
Nodes (26): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), Arena, TestAngleDiffHugeInputTerminates(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored() (+18 more)

### Community 20 - "StoreBillingPlugin"
Cohesion: 0.18
Nodes (3): Intent, StoreBillingPlugin, ServiceConnection

### Community 21 - "handlers_chat.go"
Cohesion: 0.23
Nodes (17): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+9 more)

### Community 22 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 23 - "context.Context"
Cohesion: 0.25
Nodes (17): context.Context, seedAchievements(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+9 more)

### Community 24 - "handlers_leaderboard.go"
Cohesion: 0.27
Nodes (12): cityPointsRow, cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard(), playerLeaderboardEntry(), playerLeaderboardFilter() (+4 more)

### Community 25 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 26 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.14
Nodes (7): android.content.ServiceConnection, android.os.Handler, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot, org.godotengine.godot.plugin.GodotPlugin, org.godotengine.godot.plugin.UsedByGodot

### Community 27 - "Player"
Cohesion: 0.18
Nodes (11): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), segmentHitsCircle() (+3 more)

### Community 28 - "seasonCupDefs"
Cohesion: 0.21
Nodes (19): net/http/httptest.ResponseRecorder, seasonCupCount(), defaultSeasonCups(), fallbackSeasonCups(), invalidateSeasonCupCache(), seasonCupDefs(), seasonCupID(), seasonCupThresholds() (+11 more)

### Community 29 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 30 - "Arena"
Cohesion: 0.16
Nodes (7): clampF(), Arena, parseArena(), arenaFile, Room, Arena, hashString()

### Community 31 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 32 - "WeaponStatsFor"
Cohesion: 0.14
Nodes (22): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), getCharacterHealth(), fireRateDamageComp(), fireRateMult(), SeedWeaponStats(), shopWeaponRatings() (+14 more)

### Community 33 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 34 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 35 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 36 - "applyLoadout"
Cohesion: 0.29
Nodes (13): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+5 more)

### Community 37 - "mm_backfill.go"
Cohesion: 0.25
Nodes (15): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, botsInMatchOf(), busyNamesLocked(), MatchOf(), ReleaseMatch() (+7 more)

### Community 38 - "distance"
Cohesion: 0.24
Nodes (6): arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), distance()

### Community 39 - "android.content.Intent"
Cohesion: 0.19
Nodes (9): android.app.Activity, android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override, BillingProxyActivity, Intent (+1 more)

### Community 40 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 41 - "game_modes.go"
Cohesion: 0.29
Nodes (9): defaultGameModes(), loadGameModes(), MigrateGameModes(), seedGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore(), GameModeDef (+1 more)

### Community 44 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 45 - ".getPluginSignals"
Cohesion: 0.20
Nodes (5): Override, SignalInfo, Override, SignalInfo, org.godotengine.godot.plugin.SignalInfo

### Community 46 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 47 - "MessageModel"
Cohesion: 0.33
Nodes (4): AdminCampaign, adminSendRequest, MessageModel, MessageReward

### Community 49 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 50 - "missions.go"
Cohesion: 0.13
Nodes (27): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, buildSeasonPassResponse(), MissionDifficulty, MissionMetric, buildSeasonChallengeView(), currentSeasonPass(), dailyMissionIndexes() (+19 more)

### Community 53 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 54 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 55 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 56 - "time.Duration"
Cohesion: 0.29
Nodes (6): time.Duration, Arena, allowPaced(), spawnShieldFor(), ModeOfMatch(), RoundRules

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

### Community 92 - "Hub"
Cohesion: 0.28
Nodes (5): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta()

### Community 94 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 98 - "SeedCurrencyPacks"
Cohesion: 0.48
Nodes (4): currencyPack, findCurrencyPack(), SeedCurrencyPacks(), TestSeedKeepsDatabaseDiscount()

### Community 99 - "applyMatchToSeasonStats"
Cohesion: 0.43
Nodes (8): persistProfileStats(), persistMatchMissions(), MatchParticipant, MatchResultBody, applyMatchToMissions(), applyMatchToSeasonStats(), missionDeltas(), TestMissionDeltas()

## Knowledge Gaps
- **71 isolated node(s):** `build.sh script`, `NONE`, `SERVICE`, `BROADCAST`, `build.sh script` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `WeaponStatsFor`, `weekly_rewards.go`, `admin_auth.go`, `applyMatchToSeasonStats`, `skins.go`, `withDB`, `SeedCurrencyPacks`, `Hub`, `game_modes.go`, `handlers_auth.go`, `matchmaking.go`, `time.Time`, `PlayerModel`, `handlers_chat.go`, `context.Context`, `handlers_leaderboard.go`, `seasonCupDefs`, `handlers_gift_codes.go`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `withDB`, `skins.go`, `col`, `handlers_auth.go`, `matchmaking.go`, `time.Time`, `models.go`, `missions.go`, `handlers_chat.go`, `handlers_leaderboard.go`, `seasonCupDefs`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `WeaponStatsFor`, `applyLoadout`, `col`, `distance`, `NewHub`, `statsOf`, `RoundState`, `time.Time`, `time.Duration`, `parseWSMessage`, `Player`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **Are the 175 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 175 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `NONE`, `SERVICE` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._