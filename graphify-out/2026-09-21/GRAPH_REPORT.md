# Graph Report - gun-game  (2026-09-21)

## Corpus Check
- 124 files · ~360,267 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1501 nodes · 4996 edges · 75 communities (63 shown, 12 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1304 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- missions_test.go
- main
- StoreBillingPlugin
- withDB
- context.Context
- build_arena.py
- matchmaking.go
- auth_test.go
- NewHub
- Hub
- Hub
- balance.go
- patch_scenes.py
- Player
- WeaponStatsFor
- time.Time
- testing.T
- build_rig.py
- demon_test.go
- Row Sheet UI Asset Preview Page
- ClanModel
- mustArena
- weekly_rewards.go
- abilities_test.go
- .FindPath
- handlers_chat.go
- angleDiff
- applyLoadout
- Arena
- PlayerModel
- Hub
- resetMM
- normalize_skin.py
- app.js
- deform_check.py
- handlers_auth.go
- parseWSMessage
- pathArena
- make_wind_swirls.py
- rulesForMode
- authGuard
- dependencies
- arm_angles.py
- solve
- MessageModel
- Hub
- handlers_gift_codes.go
- prepare_chat_emojis.py
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
- RoundState
- missions.go
- adminSession
- checkAndUnlockAchievements
- game_modes.go
- PlayerSeasonPass
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 182 edges
2. `httpError()` - 111 edges
3. `jsonResponse()` - 106 edges
4. `enableCORS()` - 68 edges
5. `PlayerModel` - 61 edges
6. `getPlayerByUsername()` - 53 edges
7. `Hub` - 51 edges
8. `NewHub()` - 50 edges
9. `h()` - 45 edges
10. `Player` - 44 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `TestGuardBlocksShotsAndBombs()` --calls--> `isGuarded()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `laserSegment()` --calls--> `arenaOf()`  [INFERRED]
  gun_game_server/abilities.go → gun_game_server/arena.go
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

## Communities (75 total, 12 thin omitted)

### Community 0 - "col"
Cohesion: 0.05
Nodes (187): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo.Collection, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom(), adminLoginHandler() (+179 more)

### Community 1 - "missions_test.go"
Cohesion: 0.10
Nodes (28): buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), missionDayEnd(), missionSecondsLeft(), missionSeed(), pickDailyMissions(), seasonPassLevelCost() (+20 more)

### Community 2 - "main"
Cohesion: 0.15
Nodes (21): net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminPanelEnabled(), adminSecurityHeaders(), registerAdminRoutes(), serverKeyOnly(), corsMiddleware() (+13 more)

### Community 3 - "StoreBillingPlugin"
Cohesion: 0.05
Nodes (24): android.content.Intent, android.content.ServiceConnection, android.os.Bundle, android.os.Handler, android.os.IBinder, android.os.Parcel, BazaarBillingPlugin, Override (+16 more)

### Community 4 - "withDB"
Cohesion: 0.05
Nodes (76): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+68 more)

### Community 5 - "context.Context"
Cohesion: 0.26
Nodes (16): context.Context, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems(), MigratePlayers() (+8 more)

### Community 6 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 7 - "matchmaking.go"
Cohesion: 0.11
Nodes (40): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), TestBotNamesLookHuman() (+32 more)

### Community 8 - "auth_test.go"
Cohesion: 0.14
Nodes (14): bufio.Scanner, makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestApplyDotEnvKeepsExistingEnv(), TestAuthGuardPassesThroughWithoutDatabase(), TestClaimsFromTokenInfoStrings(), TestGoogleClaimsValidation() (+6 more)

### Community 9 - "NewHub"
Cohesion: 0.11
Nodes (41): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), NewHub(), addPlayer(), containsStr() (+33 more)

### Community 10 - "Hub"
Cohesion: 0.18
Nodes (5): BotSeat, Hub, botsInMatchOf(), MatchOf(), TeamOf()

### Community 11 - "Hub"
Cohesion: 0.11
Nodes (17): github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), broadcastChatMessage(), equippedFor(), BotRuntime, Hub, Hub (+9 more)

### Community 12 - "balance.go"
Cohesion: 0.17
Nodes (20): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+12 more)

### Community 13 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 14 - "Player"
Cohesion: 0.16
Nodes (13): arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), BotRuntime, Hub, turnStep() (+5 more)

### Community 15 - "WeaponStatsFor"
Cohesion: 0.09
Nodes (32): TestFireCooldownIsAlwaysPositive(), CharacterStats(), shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds() (+24 more)

### Community 16 - "time.Time"
Cohesion: 0.07
Nodes (42): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, sync.Mutex, time.Time, AchievementDef, AdminAuditEntry, adRewardDay, BuyRequest, ChatReadBody (+34 more)

### Community 17 - "testing.T"
Cohesion: 0.10
Nodes (39): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks() (+31 more)

### Community 18 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 19 - "demon_test.go"
Cohesion: 0.16
Nodes (19): Arena, newDemon(), absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen() (+11 more)

### Community 20 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 21 - "ClanModel"
Cohesion: 0.17
Nodes (20): go.mongodb.org/mongo-driver/bson.M, cityPointsRow, ClanMember, ClanModel, clanLeaderInfo(), clanWorldRank(), cityLeaderboardEntry(), cityPointsStages() (+12 more)

### Community 22 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 23 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 24 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 25 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 26 - "handlers_chat.go"
Cohesion: 0.24
Nodes (16): ChatMessageModel, allowChatSend(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread(), fillLastMessage() (+8 more)

### Community 27 - "angleDiff"
Cohesion: 0.38
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), TestMissChanceAndFireConeCanActuallyReject(), angleDiff() (+3 more)

### Community 28 - "applyLoadout"
Cohesion: 0.29
Nodes (13): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+5 more)

### Community 29 - "Arena"
Cohesion: 0.19
Nodes (6): clampF(), Arena, arenaFile, Room, Arena, hashString()

### Community 30 - "PlayerModel"
Cohesion: 0.15
Nodes (20): buildSeasonCupsResponse(), seasonXPOf(), PlayerModel, PlayerSeasonCups, PlayerStats, currentSeasonCups(), SeasonCupClaimBody, SkinDef (+12 more)

### Community 31 - "Hub"
Cohesion: 0.18
Nodes (9): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), refreshAbilityTimers() (+1 more)

### Community 32 - "resetMM"
Cohesion: 0.39
Nodes (11): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), busyNamesLocked(), ReleaseMatch(), sweepStaleMatchesLocked(), resetMM(), seedMatch() (+3 more)

### Community 33 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 34 - "app.js"
Cohesion: 0.12
Nodes (84): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+76 more)

### Community 35 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 36 - "handlers_auth.go"
Cohesion: 0.16
Nodes (27): TestMaskEmailAndAuthPageEscaping(), googleClaims, googleConfig, googleResult, googleStartBody, applyGoogleIdentity(), asString(), authRequired() (+19 more)

### Community 37 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 38 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 39 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 40 - "rulesForMode"
Cohesion: 0.27
Nodes (8): time.Duration, Arena, TestDemonHuntRules(), rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules

### Community 41 - "authGuard"
Cohesion: 0.17
Nodes (23): guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), TestBearerToken(), TestSessionMatchesOnlyTheRightToken(), authProbe, authGuard() (+15 more)

### Community 42 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 43 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 44 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 45 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 46 - "Hub"
Cohesion: 0.18
Nodes (11): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta(), persistMatchMissions(), MatchParticipant, MatchResultBody (+3 more)

### Community 47 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 48 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 49 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 50 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 65 - "RoundState"
Cohesion: 0.27
Nodes (4): BotRuntime, Hub, DemonState, RoundState

### Community 66 - "missions.go"
Cohesion: 0.21
Nodes (16): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyBonusTier, DailyMissionDef, MissionDifficulty, MissionMetric, dailyBonusTierByNeed(), dailyMissionIndexes(), SeasonPassLadder() (+8 more)

### Community 67 - "adminSession"
Cohesion: 0.21
Nodes (11): checkAdminLogin(), loadAdminAccounts(), randomHex(), TestAdminSessionRevokedWhenAccountRemoved(), TestBanActive(), TestLoadAdminAccounts(), adminAccount, adminSession (+3 more)

### Community 68 - "checkAndUnlockAchievements"
Cohesion: 0.31
Nodes (10): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement(), persistProfileStats(), seedAchievements(), TestProfileStatsFromRound() (+2 more)

### Community 69 - "game_modes.go"
Cohesion: 0.29
Nodes (9): defaultGameModes(), loadGameModes(), MigrateGameModes(), seedGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore(), GameModeDef (+1 more)

### Community 70 - "PlayerSeasonPass"
Cohesion: 0.67
Nodes (3): buildSeasonChallengeView(), TestSeasonChallengeView(), PlayerSeasonPass

## Knowledge Gaps
- **67 isolated node(s):** `build.sh script`, `build.sh script`, `adminCtxKey`, `$app`, `nf` (+62 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `withDB`, `checkAndUnlockAchievements`, `context.Context`, `matchmaking.go`, `game_modes.go`, `authGuard`, `handlers_auth.go`, `Hub`, `balance.go`, `Hub`, `handlers_gift_codes.go`, `time.Time`, `WeaponStatsFor`, `ClanModel`, `weekly_rewards.go`, `handlers_chat.go`, `PlayerModel`?**
  _High betweenness centrality (0.129) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `RoundState`, `parseWSMessage`, `NewHub`, `Player`, `WeaponStatsFor`, `time.Time`, `angleDiff`, `applyLoadout`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `RoundState`, `NewHub`, `Hub`, `Hub`, `balance.go`, `time.Time`, `testing.T`, `mustArena`, `abilities_test.go`, `applyLoadout`, `Hub`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Are the 172 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 172 INFERRED edges - model-reasoned connections that need verification._
- **Are the 102 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 102 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `build.sh script`, `adminCtxKey` to the rest of the system?**
  _67 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.05368404860790647 - nodes in this community are weakly interconnected._