# Graph Report - gun-game  (2026-10-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1649 nodes · 5452 edges · 98 communities (79 shown, 19 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1391 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `0da417d7`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- withDB
- app.js
- context.Context
- admin_auth.go
- matchmaking.go
- handlers_auth.go
- net/http.ResponseWriter
- build_arena.py
- Hub
- RoundState
- net/http.Request
- CharacterStats
- PlayerModel
- NewHub
- models.go
- Player
- handlers_clan.go
- patch_scenes.py
- org.godotengine.godot.plugin.UsedByGodot
- admin_live.go
- testing.T
- time.Time
- handlers_chat.go
- getPlayerByID
- missions_test.go
- StoreBillingPlugin
- build_rig.py
- profileFor
- Row Sheet UI Asset Preview Page
- LoadArena
- mustArena
- demon_test.go
- abilities_test.go
- Arena
- .FindPath
- android.content.Intent
- applyLoadout
- android.os.Bundle
- col
- angleDiff
- missions.go
- authGuard
- BazaarBillingPlugin
- MyketBillingPlugin
- Hub
- BillingProxyActivity
- normalize_skin.py
- redeemGiftCodeHandler
- deform_check.py
- adRewardClaimHandler
- .teamRoomsFor
- loadOrCreateDailyMissions
- main
- pathArena
- make_wind_swirls.py
- rulesForMode
- dependencies
- arm_angles.py
- solve
- parseWSMessage
- prepare_chat_emojis.py
- check_store_apk.sh
- Mode
- strip_white_bg.py
- sweep_sniper.py
- PlayerStats
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
- admin_security.go
- weekly_rewards.go
- admin_game.go
- clientIP
- balance.go
- handlers_leaderboard.go
- ApplyMatchOutcome
- applyMatchToSeasonStats
- checkAndUnlockAchievements
- claimSeasonCupHandler

## God Nodes (most connected - your core abstractions)
1. `col()` - 186 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `Hub` - 63 edges
6. `PlayerModel` - 60 edges
7. `NewHub()` - 60 edges
8. `getPlayerByUsername()` - 54 edges
9. `h()` - 48 edges
10. `Player` - 47 edges

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

## Communities (98 total, 19 thin omitted)

### Community 0 - "withDB"
Cohesion: 0.05
Nodes (75): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+67 more)

### Community 1 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 2 - "context.Context"
Cohesion: 0.23
Nodes (18): context.Context, seedBots(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+10 more)

### Community 3 - "admin_auth.go"
Cohesion: 0.15
Nodes (22): net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders(), checkAdminLogin(), loadAdminAccounts() (+14 more)

### Community 4 - "matchmaking.go"
Cohesion: 0.06
Nodes (63): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), botSkillFor(), keysOf(), loadBotsNear(), makeBot() (+55 more)

### Community 5 - "handlers_auth.go"
Cohesion: 0.15
Nodes (26): TestGoogleConsentURLUsesPKCE(), TestMaskEmailAndAuthPageEscaping(), GoogleAuthPending, googleClaims, googleConfig, googleResult, googleStartBody, applyGoogleIdentity() (+18 more)

### Community 6 - "net/http.ResponseWriter"
Cohesion: 0.17
Nodes (32): go.mongodb.org/mongo-driver/mongo.Collection, net/http.ResponseWriter, getGameModesHandler(), selectGameModeHandler(), googleAuthPollHandler(), buyItemHandler(), readChatRoomHandler(), enableCORS() (+24 more)

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "Hub"
Cohesion: 0.11
Nodes (18): github.com/gorilla/websocket.Conn, time.Duration, Client, SetPlayerOnline(), persianDuration(), allowPaced(), equippedFor(), Hub (+10 more)

### Community 9 - "RoundState"
Cohesion: 0.12
Nodes (8): DemonState, Arena, BotRuntime, Hub, newDemon(), DemonState, Hub, RoundState

### Community 10 - "net/http.Request"
Cohesion: 0.16
Nodes (41): net/http.Request, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), audit(), writeAudit(), adminChatDeleteHandler() (+33 more)

### Community 11 - "CharacterStats"
Cohesion: 0.11
Nodes (27): TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), magazineFor(), TestNoLevelOneLoadoutOneShotsAnyone(), TestResolvedStatsStayInSaneBounds(), TestUnknownCharacterFallsBackToBalanced(), clampUnit(), getCharacterHealth() (+19 more)

### Community 12 - "PlayerModel"
Cohesion: 0.19
Nodes (21): MaxLevelOf(), PlayerModel, SkinDef, SkinEquipRequest, activeSkin(), allCharacterIDs(), characterLevel(), characterUpgradeView() (+13 more)

### Community 13 - "NewHub"
Cohesion: 0.12
Nodes (36): TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored(), TestEndingOldRoundSparesThingsNowInAnotherMatch(), TestNoHitsOnOrByDeadPlayers(), TestRapidMoveSpamIsSpeedCapped() (+28 more)

### Community 14 - "models.go"
Cohesion: 0.08
Nodes (32): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+24 more)

### Community 15 - "Player"
Cohesion: 0.15
Nodes (15): laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, turnStep() (+7 more)

### Community 16 - "handlers_clan.go"
Cohesion: 0.19
Nodes (30): adminClanKickHandler(), disbandClan(), ClanModel, clanLeaderInfo(), clanMemberRole(), clanRowLess(), clanWorldRank(), createClanHandler() (+22 more)

### Community 17 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 18 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 19 - "admin_live.go"
Cohesion: 0.29
Nodes (12): adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), dailyCounts(), Hub, humans(), kickFromHub(), runOnHub() (+4 more)

### Community 20 - "testing.T"
Cohesion: 0.10
Nodes (33): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestSameRaritySharesSamePipBudget(), TestShopRatingGapStaysSmallAcrossRarities() (+25 more)

### Community 21 - "time.Time"
Cohesion: 0.16
Nodes (11): sync.Mutex, time.Time, abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage() (+3 more)

### Community 22 - "handlers_chat.go"
Cohesion: 0.22
Nodes (19): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+11 more)

### Community 23 - "getPlayerByID"
Cohesion: 0.16
Nodes (20): adminFindPlayer(), adminPlayerHandler(), nonNilMatches(), DailyBonusClaimBody, buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler(), claimSeasonChallengeHandler() (+12 more)

### Community 24 - "missions_test.go"
Cohesion: 0.10
Nodes (27): DailyBonusTier, buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), dailyBonusTierByNeed(), missionDayEnd(), missionSecondsLeft(), missionSeed() (+19 more)

### Community 25 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 26 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 27 - "profileFor"
Cohesion: 0.17
Nodes (18): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+10 more)

### Community 28 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 29 - "LoadArena"
Cohesion: 0.21
Nodes (17): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), Hub, newRevengeRound(), TestAttackingEndsYourOwnShield(), TestJoinRoundIsIdempotent(), TestLateJoinerStillRespawns() (+9 more)

### Community 30 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 31 - "demon_test.go"
Cohesion: 0.20
Nodes (17): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+9 more)

### Community 32 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 33 - "Arena"
Cohesion: 0.22
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 34 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 35 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 36 - "applyLoadout"
Cohesion: 0.40
Nodes (10): TestBombStockIsThreePerMatch(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput() (+2 more)

### Community 37 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 38 - "col"
Cohesion: 0.16
Nodes (31): engageLockdown(), AdminCampaign, col(), getChatHistoryHandler(), getPlayerHandler(), claimAllMessagesHandler(), claimMessageRewardHandler(), claimOneMessage() (+23 more)

### Community 39 - "angleDiff"
Cohesion: 0.35
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), TestFireCooldownIsAlwaysPositive(), angleDiff() (+3 more)

### Community 40 - "missions.go"
Cohesion: 0.19
Nodes (20): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, buildSeasonPassResponse(), MissionDifficulty, MissionMetric, buildSeasonChallengeView(), dailyMissionIndexes(), ensureSeasonPass() (+12 more)

### Community 41 - "authGuard"
Cohesion: 0.15
Nodes (27): guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), TestAuthGuardPassesThroughWithoutDatabase(), TestBearerToken(), TestSessionMatchesOnlyTheRightToken(), authProbe (+19 more)

### Community 44 - "Hub"
Cohesion: 0.30
Nodes (3): minInt(), Hub, liveDelta()

### Community 45 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 46 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 47 - "redeemGiftCodeHandler"
Cohesion: 0.26
Nodes (11): adminGiftCodeRedemptionsHandler(), findAll(), createGiftCodeRequest, GiftCode, createGiftCode(), createGiftCodeHandler(), normalizeGiftCode(), randomGiftCode() (+3 more)

### Community 48 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 49 - "adRewardClaimHandler"
Cohesion: 0.39
Nodes (8): adRewardDay, adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adRewardStatusHandler(), adTokenRewarded(), missionDayKey()

### Community 50 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 51 - "loadOrCreateDailyMissions"
Cohesion: 0.25
Nodes (9): DailyMissionDoc, LiveObjective, buildObjectives(), currentSeasonPass(), loadOrCreateDailyMissions(), repairMissionStates(), TestCurrentSeasonPassNormalisesNewFields(), PlayerMissionState (+1 more)

### Community 52 - "main"
Cohesion: 0.11
Nodes (19): bufio.Scanner, nextAchievement(), EnsureAdminIndexes(), loadAdminLockdown(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestApplyDotEnvKeepsExistingEnv() (+11 more)

### Community 53 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 54 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 55 - "rulesForMode"
Cohesion: 0.38
Nodes (6): TestDemonHuntRules(), rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules

### Community 56 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 57 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 58 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 59 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 60 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 61 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 62 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 63 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 64 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 88 - "admin_security.go"
Cohesion: 0.16
Nodes (17): adminLoginBlocked(), adminLoginFailed(), cliUnlock(), hashAdminPassword(), newTOTPSecret(), runAdminCLI(), totpAt(), verifyAdminPassword() (+9 more)

### Community 89 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 90 - "admin_game.go"
Cohesion: 0.23
Nodes (17): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, adminPage(), findPage(), adminCampaignsHandler(), adminSupportListHandler(), adminClanHandler(), adminClansHandler() (+9 more)

### Community 91 - "clientIP"
Cohesion: 0.23
Nodes (13): net/http.HandlerFunc, rateBucket, clientIP(), newRateLimiter(), rateLimit(), rateLimitSensitive(), TestClientIPIgnoresForwardedHeaderByDefault(), TestClientIPTakesLastTrustedHop() (+5 more)

### Community 92 - "balance.go"
Cohesion: 0.28
Nodes (12): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), round2(), round3(), SeedCharacterStats(), shopCharacterRatings() (+4 more)

### Community 93 - "handlers_leaderboard.go"
Cohesion: 0.24
Nodes (13): go.mongodb.org/mongo-driver/bson.M, cityPointsRow, cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard(), playerLeaderboardFilter() (+5 more)

### Community 94 - "ApplyMatchOutcome"
Cohesion: 0.26
Nodes (12): ApplyMatchOutcome(), ApplyMatchResult(), defaultGameModes(), gameModeByID(), loadGameModes(), lossCoinsOf(), seedGameModes(), TestDefaultGameModesAreWellFormed() (+4 more)

### Community 95 - "applyMatchToSeasonStats"
Cohesion: 0.31
Nodes (10): persistMatchMissions(), MatchParticipant, MatchRecord, MatchResultBody, applyMatchToMissions(), applyMatchToSeasonStats(), carryPlaySeconds(), missionDeltas() (+2 more)

### Community 96 - "checkAndUnlockAchievements"
Cohesion: 0.42
Nodes (8): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), persistProfileStats(), seedAchievements(), TestProfileStatsFromRound(), UnlockedAchievement

### Community 97 - "claimSeasonCupHandler"
Cohesion: 0.53
Nodes (5): buildSeasonCupsResponse(), claimSeasonCupHandler(), getSeasonCupsHandler(), seasonXPOf(), SeasonCupClaimBody

## Knowledge Gaps
- **71 isolated node(s):** `signedPurchase`, `ACTIONS`, `$app`, `auditState`, `CHANNEL` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `withDB`, `context.Context`, `matchmaking.go`, `handlers_auth.go`, `net/http.ResponseWriter`, `Hub`, `net/http.Request`, `CharacterStats`, `PlayerModel`, `handlers_clan.go`, `admin_live.go`, `handlers_chat.go`, `getPlayerByID`, `missions.go`, `authGuard`, `redeemGiftCodeHandler`, `adRewardClaimHandler`, `loadOrCreateDailyMissions`, `main`, `weekly_rewards.go`, `admin_game.go`, `balance.go`, `handlers_leaderboard.go`, `ApplyMatchOutcome`, `applyMatchToSeasonStats`, `checkAndUnlockAchievements`, `claimSeasonCupHandler`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `applyLoadout`, `matchmaking.go`, `angleDiff`, `RoundState`, `CharacterStats`, `NewHub`, `Player`, `handlers_clan.go`, `time.Time`, `parseWSMessage`?**
  _High betweenness centrality (0.045) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `checkAndUnlockAchievements`, `claimSeasonCupHandler`, `withDB`, `PlayerStats`, `matchmaking.go`, `net/http.ResponseWriter`, `col`, `missions.go`, `authGuard`, `net/http.Request`, `models.go`, `handlers_clan.go`, `adRewardClaimHandler`, `loadOrCreateDailyMissions`, `time.Time`, `handlers_chat.go`, `getPlayerByID`, `handlers_leaderboard.go`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `signedPurchase`, `ACTIONS`, `$app` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `withDB` be split into smaller, more focused modules?**
  _Cohesion score 0.0522466039707419 - nodes in this community are weakly interconnected._