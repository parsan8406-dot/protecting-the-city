# Graph Report - gun-game  (2026-10-02)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1541 nodes · 5116 edges · 78 communities (60 shown, 18 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1341 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- withDB
- missions.go
- admin_auth.go
- StoreBillingPlugin
- col
- handlers_auth.go
- WeaponStatsFor
- build_arena.py
- net/http.Request
- Hub
- distance
- matchmaking.go
- RoundState
- testing.T
- time.Time
- handlers_chat.go
- LoadArena
- handlers_leaderboard.go
- patch_scenes.py
- countOf
- NewHub
- getPlayerByID
- build_rig.py
- Row Sheet UI Asset Preview Page
- context.Context
- Arena
- mustArena
- PlayerModel
- weekly_rewards.go
- .FindPath
- mm_backfill.go
- abilities_test.go
- Player
- checkAndUnlockAchievements
- handlers_clan.go
- applyLoadout
- net/http.ResponseWriter
- statsOf
- bot_sense_test.go
- normalize_skin.py
- balance.go
- handlers_gift_codes.go
- deform_check.py
- MessageModel
- broadcastChatMessage
- make_wind_swirls.py
- dependencies
- arm_angles.py
- solve
- parseWSMessage
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
- Override
- SignalInfo
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Hub
- BotRuntime
- Hub
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 185 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `PlayerModel` - 61 edges
6. `getPlayerByUsername()` - 53 edges
7. `Hub` - 52 edges
8. `NewHub()` - 50 edges
9. `h()` - 48 edges
10. `Player` - 44 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `coinsOf()` --calls--> `col()`  [INFERRED]
  gun_game_server/claim_null_arrays_db_test.go → gun_game_server/db.go
- `seedClaimPlayer()` --calls--> `col()`  [INFERRED]
  gun_game_server/claim_null_arrays_db_test.go → gun_game_server/db.go
- `TestDailyChestClaimWorksWhenBonusClaimedIsNull()` --calls--> `col()`  [INFERRED]
  gun_game_server/claim_null_arrays_db_test.go → gun_game_server/db.go
- `TestDailyChestClaimWorksWhenBonusClaimedIsNull()` --calls--> `missionDayKey()`  [INFERRED]
  gun_game_server/claim_null_arrays_db_test.go → gun_game_server/missions.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (78 total, 18 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "withDB"
Cohesion: 0.05
Nodes (75): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+67 more)

### Community 2 - "missions.go"
Cohesion: 0.08
Nodes (44): DailyBonusTier, DailyMissionDef, buildMissionsResponse(), MissionDifficulty, MissionMetric, buildDailyBonusView(), buildSeasonChallengeView(), dailyBonusMaxNeed() (+36 more)

### Community 3 - "admin_auth.go"
Cohesion: 0.05
Nodes (60): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders() (+52 more)

### Community 4 - "StoreBillingPlugin"
Cohesion: 0.05
Nodes (25): android.content.Intent, android.content.ServiceConnection, android.os.Bundle, android.os.Handler, android.os.IBinder, android.os.Parcel, BazaarBillingPlugin, Override (+17 more)

### Community 5 - "col"
Cohesion: 0.19
Nodes (26): col(), GenerateUniquePlayerID(), MigratePlayers(), repairPlayerUsernames(), getPlayerHandler(), claimAllMessagesHandler(), claimMessageRewardHandler(), claimOneMessage() (+18 more)

### Community 6 - "handlers_auth.go"
Cohesion: 0.08
Nodes (60): guardStatus(), seedAuthPlayer(), TestProfileStatsFromRound(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody() (+52 more)

### Community 7 - "WeaponStatsFor"
Cohesion: 0.14
Nodes (21): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), getCharacterHealth(), fireRateDamageComp(), fireRateMult(), SeedWeaponStats(), shopWeaponRatings() (+13 more)

### Community 8 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 9 - "net/http.Request"
Cohesion: 0.16
Nodes (43): net/http.Request, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), audit(), writeAudit(), adminChatDeleteHandler() (+35 more)

### Community 10 - "Hub"
Cohesion: 0.15
Nodes (11): BotRuntime, github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), Hub, hubAction, removeFromQueueLocked(), ReleaseMatchOf() (+3 more)

### Community 11 - "distance"
Cohesion: 0.16
Nodes (8): Arena, BotRuntime, Hub, patrolPoint(), BotRuntime, Hub, botSkillProfile, distance()

### Community 12 - "matchmaking.go"
Cohesion: 0.11
Nodes (38): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), TestBotNamesLookHuman() (+30 more)

### Community 13 - "RoundState"
Cohesion: 0.10
Nodes (11): Arena, Hub, newDemon(), DemonState, minInt(), LiveObjective, buildObjectives(), Hub (+3 more)

### Community 14 - "testing.T"
Cohesion: 0.08
Nodes (39): testing.T, TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget(), TestShopRatingGapStaysSmallAcrossRarities() (+31 more)

### Community 15 - "time.Time"
Cohesion: 0.06
Nodes (43): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, sync.Mutex, time.Time, AchievementDef, adRewardDay, BuyRequest, ChatReadBody, ChatReadModel (+35 more)

### Community 16 - "handlers_chat.go"
Cohesion: 0.22
Nodes (21): ChatMessageModel, allowChatSend(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread(), fillLastMessage() (+13 more)

### Community 17 - "LoadArena"
Cohesion: 0.13
Nodes (28): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), addPlayer(), containsStr(), Hub (+20 more)

### Community 18 - "handlers_leaderboard.go"
Cohesion: 0.26
Nodes (14): cityPointsRow, cityLeaderboardEntry(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard(), getLeaderboardHandler() (+6 more)

### Community 19 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 20 - "countOf"
Cohesion: 0.13
Nodes (30): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/bson.M, go.mongodb.org/mongo-driver/mongo/options.FindOptions, adminPage(), findPage(), adminCampaignsHandler(), adminSupportListHandler(), adminClansHandler() (+22 more)

### Community 21 - "NewHub"
Cohesion: 0.12
Nodes (34): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+26 more)

### Community 22 - "getPlayerByID"
Cohesion: 0.20
Nodes (20): DailyBonusClaimBody, buildSeasonPassResponse(), buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler(), claimSeasonChallengeHandler(), claimSeasonPassHandler(), levelFromExperience() (+12 more)

### Community 23 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 24 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 25 - "context.Context"
Cohesion: 0.12
Nodes (31): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, seedAchievements(), engageLockdown(), adRewardRequest, catalogPrice, EnsureCollections(), EnsureIndexes() (+23 more)

### Community 26 - "Arena"
Cohesion: 0.19
Nodes (6): clampF(), Arena, arenaFile, Room, Arena, hashString()

### Community 27 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 28 - "PlayerModel"
Cohesion: 0.16
Nodes (25): buildSeasonCupsResponse(), seasonXPOf(), equippedFor(), PlayerModel, PlayerSeasonCups, currentSeasonCups(), SeasonCupClaimBody, SkinDef (+17 more)

### Community 29 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 30 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 31 - "mm_backfill.go"
Cohesion: 0.19
Nodes (18): time.Duration, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, spawnShieldFor(), botsInMatchOf(), busyNamesLocked() (+10 more)

### Community 32 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 33 - "Player"
Cohesion: 0.17
Nodes (13): Arena, abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage() (+5 more)

### Community 34 - "checkAndUnlockAchievements"
Cohesion: 0.21
Nodes (15): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement(), persistProfileStats(), TestNextAchievementPicksClosestLocked(), persistMatchMissions() (+7 more)

### Community 35 - "handlers_clan.go"
Cohesion: 0.19
Nodes (31): adminClanKickHandler(), disbandClan(), ClanModel, clanLeaderInfo(), clanMemberRole(), clanRowLess(), clanSummary(), clanWorldRank() (+23 more)

### Community 36 - "applyLoadout"
Cohesion: 0.23
Nodes (14): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+6 more)

### Community 37 - "net/http.ResponseWriter"
Cohesion: 0.17
Nodes (31): currencyPack, go.mongodb.org/mongo-driver/mongo.Collection, net/http.ResponseWriter, googleAuthPollHandler(), writeGoogleResult(), buyItemHandler(), getClansHandler(), claimSeasonCupHandler() (+23 more)

### Community 38 - "statsOf"
Cohesion: 0.22
Nodes (15): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), arenaOf(), turnStep() (+7 more)

### Community 39 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 40 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 41 - "balance.go"
Cohesion: 0.20
Nodes (17): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+9 more)

### Community 42 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 43 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 44 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 45 - "broadcastChatMessage"
Cohesion: 0.40
Nodes (5): broadcastChatMessage(), NotifyEveryone(), NotifyUsers(), queueNotify(), userMessage

### Community 46 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 48 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 49 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 50 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 51 - "parseWSMessage"
Cohesion: 0.32
Nodes (5): parseWSMessage(), ServeWs(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 52 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 53 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 54 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **68 isolated node(s):** `ACTIONS`, `$app`, `auditState`, `CHANNEL`, `chatState` (+63 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `withDB`, `admin_auth.go`, `handlers_auth.go`, `WeaponStatsFor`, `net/http.Request`, `Hub`, `matchmaking.go`, `handlers_chat.go`, `handlers_leaderboard.go`, `countOf`, `getPlayerByID`, `context.Context`, `PlayerModel`, `weekly_rewards.go`, `checkAndUnlockAchievements`, `handlers_clan.go`, `net/http.ResponseWriter`, `balance.go`, `handlers_gift_codes.go`?**
  _High betweenness centrality (0.092) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `abilities_test.go`, `applyLoadout`, `statsOf`, `bot_sense_test.go`, `Hub`, `distance`, `RoundState`, `time.Time`, `LoadArena`, `mustArena`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `Player`, `handlers_clan.go`, `applyLoadout`, `statsOf`, `WeaponStatsFor`, `distance`, `broadcastChatMessage`, `time.Time`, `parseWSMessage`, `countOf`, `NewHub`, `PlayerModel`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Are the 175 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 175 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ACTIONS`, `$app`, `auditState` to the rest of the system?**
  _68 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._