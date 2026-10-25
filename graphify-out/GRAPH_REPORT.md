# Graph Report - gun-game  (2026-10-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1648 nodes · 5452 edges · 87 communities (68 shown, 19 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1391 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- missions_test.go
- admin_auth.go
- PlayerModel
- matchmaking.go
- net/http.ResponseWriter
- handlers_auth.go
- build_arena.py
- Hub
- net/http.Request
- RoundState
- testing.T
- NewHub
- CharacterStats
- handlers_clan.go
- Player
- patch_scenes.py
- org.godotengine.godot.plugin.UsedByGodot
- col
- models.go
- time.Time
- context.Context
- adminSendMessageHandler
- StoreBillingPlugin
- build_rig.py
- withDB
- admin_live.go
- profileFor
- Row Sheet UI Asset Preview Page
- mustArena
- getPlayerByID
- missions.go
- demon_test.go
- abilities_test.go
- Arena
- buildSeasonPassResponse
- .FindPath
- android.content.Intent
- android.os.Bundle
- Hub
- applyLoadout
- angleDiff
- loadOrCreateDailyMissions
- BazaarBillingPlugin
- MyketBillingPlugin
- BillingProxyActivity
- normalize_skin.py
- redeemGiftCodeHandler
- deform_check.py
- rulesForMode
- seasonPassReward
- adRewardClaimHandler
- .teamRoomsFor
- PlayerStats
- pathArena
- make_wind_swirls.py
- dependencies
- arm_angles.py
- solve
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
- Arena
- BotRuntime
- Arena
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 186 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `Hub` - 63 edges
6. `PlayerModel` - 61 edges
7. `NewHub()` - 60 edges
8. `getPlayerByUsername()` - 54 edges
9. `h()` - 48 edges
10. `Player` - 47 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `buildSeasonPassResponse()` --calls--> `SeasonPassLadder()`  [INFERRED]
  gun_game_server/handlers_missions.go → gun_game_server/missions.go
- `buildSeasonPassResponse()` --calls--> `SeasonPassPremiumLadder()`  [INFERRED]
  gun_game_server/handlers_missions.go → gun_game_server/missions.go
- `TestSeasonPassTierNotFreeAtZeroXP()` --calls--> `buildSeasonPassResponse()`  [INFERRED]
  gun_game_server/missions_test.go → gun_game_server/handlers_missions.go
- `TestSkinsComeOnlyFromBattlePass()` --calls--> `isSkinID()`  [INFERRED]
  gun_game_server/skins_test.go → gun_game_server/skins.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (87 total, 19 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "missions_test.go"
Cohesion: 0.12
Nodes (23): DailyBonusTier, buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), dailyBonusTierByNeed(), missionDayEnd(), missionSecondsLeft(), missionSeed() (+15 more)

### Community 2 - "admin_auth.go"
Cohesion: 0.06
Nodes (59): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders() (+51 more)

### Community 3 - "PlayerModel"
Cohesion: 0.12
Nodes (33): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+25 more)

### Community 4 - "matchmaking.go"
Cohesion: 0.06
Nodes (63): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), botSkillFor(), keysOf(), loadBotsNear(), makeBot() (+55 more)

### Community 5 - "net/http.ResponseWriter"
Cohesion: 0.12
Nodes (54): go.mongodb.org/mongo-driver/mongo.Collection, net/http.ResponseWriter, BuyRequest, getGameModesHandler(), selectGameModeHandler(), adRewardStatusHandler(), googleAuthPollHandler(), buyItemHandler() (+46 more)

### Community 6 - "handlers_auth.go"
Cohesion: 0.07
Nodes (63): guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestAuthGuardPassesThroughWithoutDatabase() (+55 more)

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "Hub"
Cohesion: 0.11
Nodes (18): github.com/gorilla/websocket.Conn, time.Duration, Client, SetPlayerOnline(), persianDuration(), allowPaced(), equippedFor(), Hub (+10 more)

### Community 9 - "net/http.Request"
Cohesion: 0.16
Nodes (41): net/http.Request, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), audit(), writeAudit(), adminChatDeleteHandler() (+33 more)

### Community 10 - "RoundState"
Cohesion: 0.12
Nodes (8): DemonState, Arena, BotRuntime, Hub, newDemon(), DemonState, Hub, RoundState

### Community 11 - "testing.T"
Cohesion: 0.15
Nodes (23): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 12 - "NewHub"
Cohesion: 0.09
Nodes (53): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored() (+45 more)

### Community 13 - "CharacterStats"
Cohesion: 0.09
Nodes (34): TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), shopRating(), TestNewGameplayHooksStayModerate(), TestNoLevelOneLoadoutOneShotsAnyone(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter() (+26 more)

### Community 14 - "handlers_clan.go"
Cohesion: 0.19
Nodes (32): adminClanKickHandler(), disbandClan(), ClanModel, clanLeaderInfo(), clanMemberRole(), clanRowLess(), clanSummary(), clanWorldRank() (+24 more)

### Community 15 - "Player"
Cohesion: 0.15
Nodes (15): laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, turnStep() (+7 more)

### Community 16 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 17 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 18 - "col"
Cohesion: 0.20
Nodes (25): adminChatHandler(), engageLockdown(), ChatMessageModel, col(), allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople() (+17 more)

### Community 19 - "models.go"
Cohesion: 0.08
Nodes (33): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanJoinRequestModel (+25 more)

### Community 20 - "time.Time"
Cohesion: 0.16
Nodes (11): sync.Mutex, time.Time, abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage() (+3 more)

### Community 21 - "context.Context"
Cohesion: 0.05
Nodes (72): context.Context, go.mongodb.org/mongo-driver/bson.M, go.mongodb.org/mongo-driver/mongo.IndexModel, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement() (+64 more)

### Community 22 - "adminSendMessageHandler"
Cohesion: 0.14
Nodes (23): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, adminPage(), findPage(), adminCampaignsHandler(), adminSendMessageHandler(), adminSupportListHandler(), adminSupportTicketHandler() (+15 more)

### Community 23 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 24 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 25 - "withDB"
Cohesion: 0.05
Nodes (77): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+69 more)

### Community 26 - "admin_live.go"
Cohesion: 0.29
Nodes (12): adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), dailyCounts(), Hub, humans(), kickFromHub(), runOnHub() (+4 more)

### Community 27 - "profileFor"
Cohesion: 0.17
Nodes (18): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+10 more)

### Community 28 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 29 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 30 - "getPlayerByID"
Cohesion: 0.14
Nodes (22): DailyBonusClaimBody, buildSeasonCupsResponse(), claimSeasonCupHandler(), getSeasonCupsHandler(), seasonXPOf(), buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler() (+14 more)

### Community 31 - "missions.go"
Cohesion: 0.33
Nodes (12): DailyMissionDef, persistMatchMissions(), MatchParticipant, MissionDifficulty, MissionMetric, applyMatchToMissions(), applyMatchToSeasonStats(), carryPlaySeconds() (+4 more)

### Community 32 - "demon_test.go"
Cohesion: 0.20
Nodes (17): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+9 more)

### Community 33 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 34 - "Arena"
Cohesion: 0.22
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 35 - "buildSeasonPassResponse"
Cohesion: 0.22
Nodes (13): buildSeasonPassResponse(), buildSeasonChallengeView(), currentSeasonPass(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestCurrentSeasonPassNormalisesNewFields() (+5 more)

### Community 36 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 37 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 38 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 39 - "Hub"
Cohesion: 0.30
Nodes (3): minInt(), Hub, liveDelta()

### Community 40 - "applyLoadout"
Cohesion: 0.29
Nodes (13): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+5 more)

### Community 41 - "angleDiff"
Cohesion: 0.35
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), TestFireCooldownIsAlwaysPositive(), angleDiff() (+3 more)

### Community 42 - "loadOrCreateDailyMissions"
Cohesion: 0.36
Nodes (6): DailyMissionDoc, LiveObjective, buildObjectives(), loadOrCreateDailyMissions(), repairMissionStates(), PlayerMissionState

### Community 45 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 46 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 47 - "redeemGiftCodeHandler"
Cohesion: 0.39
Nodes (8): createGiftCodeRequest, GiftCode, createGiftCode(), createGiftCodeHandler(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeHandler(), redeemGiftCodeRequest

### Community 48 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 49 - "rulesForMode"
Cohesion: 0.38
Nodes (6): TestDemonHuntRules(), rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules

### Community 50 - "seasonPassReward"
Cohesion: 0.43
Nodes (8): SeasonPassLadder(), SeasonPassPremiumLadder(), seasonPassPremiumReward(), seasonPassReward(), TestPremiumLadderBeatsFree(), TestSeasonPassRewardsAlwaysGiveSomething(), SeasonPassReward, TestSkinsComeOnlyFromBattlePass()

### Community 51 - "adRewardClaimHandler"
Cohesion: 0.43
Nodes (7): adRewardDay, adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adTokenRewarded(), missionDayKey()

### Community 52 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 55 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 56 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 59 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 60 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 61 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 63 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 64 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 65 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 66 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 67 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 68 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **71 isolated node(s):** `ACTIONS`, `$app`, `auditState`, `CHANNEL`, `chatState` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `admin_auth.go`, `PlayerModel`, `matchmaking.go`, `net/http.ResponseWriter`, `handlers_auth.go`, `Hub`, `net/http.Request`, `loadOrCreateDailyMissions`, `CharacterStats`, `handlers_clan.go`, `redeemGiftCodeHandler`, `adRewardClaimHandler`, `context.Context`, `adminSendMessageHandler`, `withDB`, `admin_live.go`, `getPlayerByID`, `missions.go`?**
  _High betweenness centrality (0.108) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `matchmaking.go`, `applyLoadout`, `angleDiff`, `RoundState`, `NewHub`, `CharacterStats`, `handlers_clan.go`, `Player`, `time.Time`, `parseWSMessage`?**
  _High betweenness centrality (0.042) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `abilities_test.go`, `Arena`, `PlayerModel`, `applyLoadout`, `Hub`, `RoundState`, `testing.T`, `angleDiff`, `NewHub`, `models.go`, `time.Time`, `profileFor`, `mustArena`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ACTIONS`, `$app`, `auditState` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._