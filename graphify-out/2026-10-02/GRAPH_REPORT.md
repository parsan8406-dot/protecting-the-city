# Graph Report - gun-game  (2026-09-21)

## Corpus Check
- 126 files · ~363,314 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1532 nodes · 5118 edges · 78 communities (66 shown, 12 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1341 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- missions_test.go
- admin_auth.go
- StoreBillingPlugin
- withDB
- context.Context
- build_arena.py
- matchmaking.go
- testing.T
- LoadArena
- net/http.ResponseWriter
- Hub
- handlers_clan.go
- patch_scenes.py
- Player
- skins.go
- models.go
- bot_sense_test.go
- build_rig.py
- demon_test.go
- Row Sheet UI Asset Preview Page
- PlayerModel
- mustArena
- weekly_rewards.go
- abilities_test.go
- .FindPath
- handlers_chat.go
- angleDiff
- applyLoadout
- Arena
- time.Time
- Hub
- mm_backfill.go
- normalize_skin.py
- app.js
- deform_check.py
- handlers_auth.go
- parseWSMessage
- pathArena
- make_wind_swirls.py
- time.Duration
- adminPlayerHandler
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
- getPlayerByID
- checkAndUnlockAchievements
- gameModeByID
- NewHub
- makeBot
- applyMatchToSeasonStats
- googleClaims
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 185 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `PlayerModel` - 61 edges
6. `getPlayerByUsername()` - 53 edges
7. `Hub` - 51 edges
8. `NewHub()` - 50 edges
9. `h()` - 48 edges
10. `Player` - 44 edges

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

## Communities (78 total, 12 thin omitted)

### Community 0 - "col"
Cohesion: 0.11
Nodes (62): go.mongodb.org/mongo-driver/mongo.Collection, engageLockdown(), col(), getGameModesHandler(), selectGameModeHandler(), adRewardStatusHandler(), buyItemHandler(), readChatRoomHandler() (+54 more)

### Community 1 - "missions_test.go"
Cohesion: 0.13
Nodes (19): buildDailyBonusView(), dailyBonusMaxNeed(), missionSeed(), pickDailyMissions(), seasonPassProgress(), TestBuildDailyBonusViewDoesNotMutateTable(), TestBuildDailyBonusViewStates(), TestCurrentSeasonPassNormalisesNewFields() (+11 more)

### Community 2 - "admin_auth.go"
Cohesion: 0.06
Nodes (58): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders() (+50 more)

### Community 3 - "StoreBillingPlugin"
Cohesion: 0.05
Nodes (24): android.content.Intent, android.content.ServiceConnection, android.os.Bundle, android.os.Handler, android.os.IBinder, android.os.Parcel, BazaarBillingPlugin, Override (+16 more)

### Community 4 - "withDB"
Cohesion: 0.05
Nodes (73): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+65 more)

### Community 5 - "context.Context"
Cohesion: 0.22
Nodes (18): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+10 more)

### Community 6 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 7 - "matchmaking.go"
Cohesion: 0.19
Nodes (24): formMatchLocked(), matchmakingStatusHandler(), peersOfLocked(), trophyGap(), tryFormMatchLocked(), maybeBackfill(), queuedLocked(), enqueue() (+16 more)

### Community 8 - "testing.T"
Cohesion: 0.08
Nodes (39): testing.T, nextAchievement(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestAuthGuardPassesThroughWithoutDatabase(), TestBearerToken(), TestClaimsFromTokenInfoStrings() (+31 more)

### Community 9 - "LoadArena"
Cohesion: 0.13
Nodes (28): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), addPlayer(), containsStr(), Hub (+20 more)

### Community 10 - "net/http.ResponseWriter"
Cohesion: 0.13
Nodes (53): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler() (+45 more)

### Community 11 - "Hub"
Cohesion: 0.12
Nodes (16): github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), BotRuntime, Hub, Hub, NotifyEveryone(), NotifyUsers() (+8 more)

### Community 12 - "handlers_clan.go"
Cohesion: 0.17
Nodes (35): adminClanKickHandler(), adminClansHandler(), disbandClan(), ClanModel, newID(), clanLeaderInfo(), clanMemberRole(), clanRowLess() (+27 more)

### Community 13 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 14 - "Player"
Cohesion: 0.16
Nodes (13): arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), BotRuntime, Hub, turnStep() (+5 more)

### Community 15 - "skins.go"
Cohesion: 0.06
Nodes (56): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+48 more)

### Community 16 - "models.go"
Cohesion: 0.07
Nodes (30): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+22 more)

### Community 17 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 18 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 19 - "demon_test.go"
Cohesion: 0.14
Nodes (23): Arena, newDemon(), absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen() (+15 more)

### Community 20 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 21 - "PlayerModel"
Cohesion: 0.16
Nodes (24): cityPointsRow, buildSeasonCupsResponse(), cityLeaderboardEntry(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard() (+16 more)

### Community 22 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 23 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 24 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 25 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 26 - "handlers_chat.go"
Cohesion: 0.22
Nodes (21): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+13 more)

### Community 27 - "angleDiff"
Cohesion: 0.44
Nodes (10): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), angleDiff(), clampRotation() (+2 more)

### Community 28 - "applyLoadout"
Cohesion: 0.40
Nodes (10): TestBombStockIsThreePerMatch(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput() (+2 more)

### Community 29 - "Arena"
Cohesion: 0.19
Nodes (6): clampF(), Arena, arenaFile, Room, Arena, hashString()

### Community 30 - "time.Time"
Cohesion: 0.15
Nodes (21): sync.Mutex, time.Time, AdminAuditEntry, adRewardDay, adRewardRequest, DailyMissionDoc, giftFailLimiter, GoogleAuthPending (+13 more)

### Community 31 - "Hub"
Cohesion: 0.16
Nodes (10): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), refreshAbilityTimers() (+2 more)

### Community 32 - "mm_backfill.go"
Cohesion: 0.25
Nodes (15): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, botsInMatchOf(), busyNamesLocked(), MatchOf(), ReleaseMatch() (+7 more)

### Community 33 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 34 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 35 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 36 - "handlers_auth.go"
Cohesion: 0.12
Nodes (45): guardStatus(), TestProtectedAccountFlow(), TestMaskEmailAndAuthPageEscaping(), TestSessionMatchesOnlyTheRightToken(), authProbe, googleConfig, googleResult, googleStartBody (+37 more)

### Community 37 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 38 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 39 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 40 - "time.Duration"
Cohesion: 0.33
Nodes (5): time.Duration, Arena, equippedFor(), spawnShieldFor(), ModeOfMatch()

### Community 41 - "adminPlayerHandler"
Cohesion: 0.17
Nodes (19): go.mongodb.org/mongo-driver/bson.M, fanOutMessage(), adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), dailyCounts(), Hub, humans() (+11 more)

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
Cohesion: 0.20
Nodes (8): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta(), buildSeasonChallengeView(), TestSeasonChallengeView(), PlayerSeasonPass

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
Cohesion: 0.14
Nodes (5): BotRuntime, Hub, DemonState, Hub, RoundState

### Community 66 - "missions.go"
Cohesion: 0.22
Nodes (17): DailyBonusTier, DailyMissionDef, MissionDifficulty, MissionMetric, dailyBonusTierByNeed(), SeasonPassLadder(), seasonPassLevelCost(), SeasonPassPremiumLadder() (+9 more)

### Community 67 - "getPlayerByID"
Cohesion: 0.24
Nodes (17): DailyBonusClaimBody, buildSeasonPassResponse(), buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler(), claimSeasonChallengeHandler(), claimSeasonPassHandler(), levelFromExperience() (+9 more)

### Community 68 - "checkAndUnlockAchievements"
Cohesion: 0.30
Nodes (10): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), persistProfileStats(), seedAchievements(), seedAuthPlayer(), TestProfileStatsFromRound() (+2 more)

### Community 69 - "gameModeByID"
Cohesion: 0.27
Nodes (10): defaultGameModes(), gameModeByID(), loadGameModes(), MigrateGameModes(), seedGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore() (+2 more)

### Community 70 - "NewHub"
Cohesion: 0.33
Nodes (13): NewHub(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestOnlyTheWinningTeamWinsANormalRound() (+5 more)

### Community 71 - "makeBot"
Cohesion: 0.24
Nodes (12): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), withinWindow() (+4 more)

### Community 72 - "applyMatchToSeasonStats"
Cohesion: 0.39
Nodes (8): persistMatchMissions(), MatchParticipant, MatchRecord, MatchResultBody, applyMatchToMissions(), applyMatchToSeasonStats(), missionDeltas(), TestMissionDeltas()

### Community 73 - "googleClaims"
Cohesion: 0.52
Nodes (6): googleClaims, asString(), claimsFromMap(), exchangeGoogleCode(), parseIDTokenPayload(), verifyGoogleIDToken()

## Knowledge Gaps
- **68 isolated node(s):** `build.sh script`, `build.sh script`, `adminCtxKey`, `$app`, `nf` (+63 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `admin_auth.go`, `withDB`, `context.Context`, `net/http.ResponseWriter`, `Hub`, `handlers_clan.go`, `skins.go`, `PlayerModel`, `weekly_rewards.go`, `handlers_chat.go`, `time.Time`, `handlers_auth.go`, `adminPlayerHandler`, `handlers_gift_codes.go`, `getPlayerByID`, `checkAndUnlockAchievements`, `gameModeByID`, `makeBot`, `applyMatchToSeasonStats`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `RoundState`, `LoadArena`, `Hub`, `skins.go`, `models.go`, `bot_sense_test.go`, `mustArena`, `abilities_test.go`, `applyLoadout`, `time.Time`, `Hub`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `col`, `getPlayerByID`, `checkAndUnlockAchievements`, `withDB`, `handlers_auth.go`, `makeBot`, `adminPlayerHandler`, `net/http.ResponseWriter`, `handlers_clan.go`, `MessageModel`, `Hub`, `skins.go`, `models.go`, `handlers_chat.go`, `time.Time`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Are the 175 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 175 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `build.sh script`, `adminCtxKey` to the rest of the system?**
  _68 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.11002331002331002 - nodes in this community are weakly interconnected._