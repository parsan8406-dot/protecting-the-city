# Graph Report - gun-game  (2026-10-26)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1649 nodes · 5452 edges · 96 communities (78 shown, 18 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1391 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3f3e2a38`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- missions.go
- matchmaking.go
- httpError
- build_arena.py
- Hub
- RoundState
- net/http.ResponseWriter
- CharacterStats
- NewHub
- handlers_clan.go
- models.go
- Player
- col
- patch_scenes.py
- org.godotengine.godot.plugin.UsedByGodot
- admin_auth.go
- testing.T
- handlers_auth.go
- time.Time
- admin_security.go
- context.Context
- StoreBillingPlugin
- handlers_chat.go
- build_rig.py
- TestIAPVerifyWithSignedReceipt
- seasonCupDefs
- profileFor
- PlayerModel
- Row Sheet UI Asset Preview Page
- LoadArena
- mustArena
- authGuard
- handlers_leaderboard.go
- go.mongodb.org/mongo-driver/bson.M
- weekly_rewards.go
- demon_test.go
- main
- abilities_test.go
- Arena
- .FindPath
- auth_test.go
- withDB
- balance.go
- android.content.Intent
- applyLoadout
- ApplyMatchOutcome
- openLuckyBox
- android.os.Bundle
- angleDiff
- BazaarBillingPlugin
- MyketBillingPlugin
- BillingProxyActivity
- normalize_skin.py
- checkAndUnlockAchievements
- adRewardClaimHandler
- redeemGiftCodeHandler
- deform_check.py
- .teamRoomsFor
- characterUpgradeView
- seedClaimPlayer
- findGemPackByProduct
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
6. `PlayerModel` - 60 edges
7. `NewHub()` - 60 edges
8. `getPlayerByUsername()` - 54 edges
9. `h()` - 48 edges
10. `Player` - 47 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `TestAssistCreditedToRecentTeammateDamager()` --calls--> `liveDelta()`  [INFERRED]
  gun_game_server/hub_hardening_test.go → gun_game_server/match_objectives.go
- `persistMatchMissions()` --calls--> `persistProfileStats()`  [INFERRED]
  gun_game_server/match_objectives.go → gun_game_server/achievements.go
- `persistMatchMissions()` --calls--> `gameModeByID()`  [INFERRED]
  gun_game_server/match_objectives.go → gun_game_server/game_modes.go
- `persistMatchMissions()` --calls--> `getPlayerByUsername()`  [INFERRED]
  gun_game_server/match_objectives.go → gun_game_server/handlers_social.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (96 total, 18 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "missions.go"
Cohesion: 0.06
Nodes (65): DailyBonusTier, DailyMissionDef, DailyMissionDoc, buildMissionsResponse(), buildSeasonPassResponse(), minInt(), LiveObjective, buildObjectives() (+57 more)

### Community 2 - "matchmaking.go"
Cohesion: 0.06
Nodes (62): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), botSkillFor(), keysOf(), loadBotsNear(), makeBot() (+54 more)

### Community 3 - "httpError"
Cohesion: 0.10
Nodes (62): go.mongodb.org/mongo-driver/mongo.Collection, adminFindPlayer(), BuyRequest, DailyBonusClaimBody, googleAuthPollHandler(), buyItemHandler(), enableCORS(), equipItemHandler() (+54 more)

### Community 4 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 5 - "Hub"
Cohesion: 0.11
Nodes (15): github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), equippedFor(), Hub, Hub, loadoutOf(), NotifyEveryone() (+7 more)

### Community 6 - "RoundState"
Cohesion: 0.12
Nodes (8): DemonState, Arena, BotRuntime, Hub, newDemon(), DemonState, Hub, RoundState

### Community 7 - "net/http.ResponseWriter"
Cohesion: 0.16
Nodes (41): net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), audit(), writeAudit() (+33 more)

### Community 8 - "CharacterStats"
Cohesion: 0.09
Nodes (34): TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), shopRating(), TestNewGameplayHooksStayModerate(), TestNoLevelOneLoadoutOneShotsAnyone(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter() (+26 more)

### Community 9 - "NewHub"
Cohesion: 0.13
Nodes (34): TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored(), TestEndingOldRoundSparesThingsNowInAnotherMatch(), TestNoHitsOnOrByDeadPlayers(), TestRapidMoveSpamIsSpeedCapped() (+26 more)

### Community 10 - "handlers_clan.go"
Cohesion: 0.18
Nodes (33): adminClanKickHandler(), disbandClan(), ClanModel, clanLeaderInfo(), clanMemberRole(), clanRowLess(), clanSummary(), clanWorldRank() (+25 more)

### Community 11 - "models.go"
Cohesion: 0.08
Nodes (32): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanJoinRequestModel (+24 more)

### Community 12 - "Player"
Cohesion: 0.15
Nodes (15): laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, turnStep() (+7 more)

### Community 13 - "col"
Cohesion: 0.14
Nodes (27): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, adminPage(), findPage(), adminCampaignsHandler(), adminChatHandler(), adminSendMessageHandler(), adminSupportListHandler() (+19 more)

### Community 14 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 15 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 16 - "admin_auth.go"
Cohesion: 0.16
Nodes (21): net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders(), checkAdminLogin(), loadAdminAccounts() (+13 more)

### Community 17 - "testing.T"
Cohesion: 0.15
Nodes (23): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 18 - "handlers_auth.go"
Cohesion: 0.15
Nodes (26): TestGoogleConsentURLUsesPKCE(), TestMaskEmailAndAuthPageEscaping(), GoogleAuthPending, googleClaims, googleConfig, googleResult, googleStartBody, applyGoogleIdentity() (+18 more)

### Community 19 - "time.Time"
Cohesion: 0.16
Nodes (11): sync.Mutex, time.Time, abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage() (+3 more)

### Community 20 - "admin_security.go"
Cohesion: 0.17
Nodes (16): adminLoginBlocked(), adminLoginFailed(), cliUnlock(), hashAdminPassword(), newTOTPSecret(), runAdminCLI(), totpAt(), verifyAdminPassword() (+8 more)

### Community 21 - "context.Context"
Cohesion: 0.18
Nodes (22): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, seedAchievements(), seedBots(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID() (+14 more)

### Community 22 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 23 - "handlers_chat.go"
Cohesion: 0.21
Nodes (22): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+14 more)

### Community 24 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 25 - "TestIAPVerifyWithSignedReceipt"
Cohesion: 0.17
Nodes (19): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, storeAPIConfigured(), verifyPurchase(), verifyStorePurchase(), envOr(), iapPackageName(), storePublicKey() (+11 more)

### Community 26 - "seasonCupDefs"
Cohesion: 0.20
Nodes (20): net/http/httptest.ResponseRecorder, PlayerSeasonCups, currentSeasonCups(), defaultSeasonCups(), fallbackSeasonCups(), invalidateSeasonCupCache(), seasonCupDefs(), seasonCupID() (+12 more)

### Community 27 - "profileFor"
Cohesion: 0.17
Nodes (18): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+10 more)

### Community 28 - "PlayerModel"
Cohesion: 0.17
Nodes (17): PlayerModel, PlayerStats, PublicProfile, RecentMatch, SkinDef, SkinEquipRequest, activeSkin(), allCharacterIDs() (+9 more)

### Community 29 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 30 - "LoadArena"
Cohesion: 0.18
Nodes (19): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), TestTeamRoomsAreStablePerMatch(), TestTeamsSpawnTogetherAndApart(), Hub, newRevengeRound(), TestAttackingEndsYourOwnShield() (+11 more)

### Community 31 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 32 - "authGuard"
Cohesion: 0.15
Nodes (27): guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), TestAuthGuardPassesThroughWithoutDatabase(), TestBearerToken(), TestSessionMatchesOnlyTheRightToken(), authProbe (+19 more)

### Community 33 - "handlers_leaderboard.go"
Cohesion: 0.17
Nodes (18): cityPointsRow, buildSeasonCupsResponse(), claimSeasonCupHandler(), getSeasonCupsHandler(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard() (+10 more)

### Community 34 - "go.mongodb.org/mongo-driver/bson.M"
Cohesion: 0.18
Nodes (18): go.mongodb.org/mongo-driver/bson.M, iapRow(), adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), dailyCounts(), Hub, humans() (+10 more)

### Community 35 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 36 - "demon_test.go"
Cohesion: 0.20
Nodes (17): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+9 more)

### Community 37 - "main"
Cohesion: 0.14
Nodes (20): net/http.HandlerFunc, EnsureAdminIndexes(), adminBasePath(), loadAdminLockdown(), TestServerKeyOnlyIsClosedWithoutKey(), serverKeyOnly(), corsMiddleware(), main() (+12 more)

### Community 38 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 39 - "Arena"
Cohesion: 0.22
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 40 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 41 - "auth_test.go"
Cohesion: 0.16
Nodes (12): bufio.Scanner, makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestApplyDotEnvKeepsExistingEnv(), TestClaimsFromTokenInfoStrings(), TestGoogleClaimsValidation(), TestPersonalizeBroadcasts() (+4 more)

### Community 42 - "withDB"
Cohesion: 0.36
Nodes (14): TestBuyItemWorksWithNullOwnedArrays(), TestLuckyBoxChargesAndGrants(), reload(), seedRewardPlayer(), TestDrawPaysHalfCoinsAndNoTrophies(), TestTrophiesNeverGoNegativeOnALoss(), TestWinningPaysTrophiesCoinsAndXP(), withDB() (+6 more)

### Community 43 - "balance.go"
Cohesion: 0.28
Nodes (12): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), round2(), round3(), SeedCharacterStats(), shopCharacterRatings() (+4 more)

### Community 44 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 45 - "applyLoadout"
Cohesion: 0.29
Nodes (13): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+5 more)

### Community 46 - "ApplyMatchOutcome"
Cohesion: 0.27
Nodes (12): ApplyMatchOutcome(), ApplyMatchResult(), defaultGameModes(), gameModeByID(), loadGameModes(), lossCoinsOf(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane() (+4 more)

### Community 47 - "openLuckyBox"
Cohesion: 0.31
Nodes (12): drawLuckyBox(), luckyBoxChoices(), luckyBoxHandler(), luckyBoxInfo(), luckyBoxPool(), luckyBoxPrizeName(), openLuckyBox(), TestLuckyBoxDrawIsSpreadAndWeighted() (+4 more)

### Community 48 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 49 - "angleDiff"
Cohesion: 0.35
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), TestFireCooldownIsAlwaysPositive(), angleDiff() (+3 more)

### Community 52 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 53 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 54 - "checkAndUnlockAchievements"
Cohesion: 0.33
Nodes (9): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement(), persistProfileStats(), TestProfileStatsFromRound(), TestNextAchievementPicksClosestLocked() (+1 more)

### Community 55 - "adRewardClaimHandler"
Cohesion: 0.39
Nodes (8): adRewardDay, adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adRewardStatusHandler(), adTokenRewarded(), missionDayKey()

### Community 57 - "redeemGiftCodeHandler"
Cohesion: 0.39
Nodes (8): createGiftCodeRequest, GiftCode, createGiftCode(), createGiftCodeHandler(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeHandler(), redeemGiftCodeRequest

### Community 58 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 59 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 60 - "characterUpgradeView"
Cohesion: 0.39
Nodes (7): MaxLevelOf(), characterLevel(), characterUpgradeView(), combatSummary(), TestActiveSkinFallsBackToDefault(), TestUpgradeCostAndLevels(), upgradeCost()

### Community 61 - "seedClaimPlayer"
Cohesion: 0.61
Nodes (7): coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull()

### Community 62 - "findGemPackByProduct"
Cohesion: 0.43
Nodes (5): currencyPack, findCurrencyPack(), findGemPackByProduct(), SeedCurrencyPacks(), TestSeedKeepsDatabaseDiscount()

### Community 63 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 64 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 65 - "rulesForMode"
Cohesion: 0.27
Nodes (9): time.Duration, TestDemonHuntRules(), persianDuration(), allowPaced(), rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules() (+1 more)

### Community 66 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 67 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 68 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 69 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 70 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 71 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 72 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 73 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 74 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **71 isolated node(s):** `ACTIONS`, `$app`, `auditState`, `CHANNEL`, `chatState` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `missions.go`, `matchmaking.go`, `httpError`, `Hub`, `net/http.ResponseWriter`, `CharacterStats`, `handlers_clan.go`, `handlers_auth.go`, `context.Context`, `handlers_chat.go`, `TestIAPVerifyWithSignedReceipt`, `seasonCupDefs`, `PlayerModel`, `authGuard`, `handlers_leaderboard.go`, `go.mongodb.org/mongo-driver/bson.M`, `weekly_rewards.go`, `main`, `withDB`, `balance.go`, `ApplyMatchOutcome`, `openLuckyBox`, `checkAndUnlockAchievements`, `adRewardClaimHandler`, `redeemGiftCodeHandler`, `seedClaimPlayer`, `findGemPackByProduct`?**
  _High betweenness centrality (0.097) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `rulesForMode`, `matchmaking.go`, `parseWSMessage`, `RoundState`, `CharacterStats`, `NewHub`, `handlers_clan.go`, `Player`, `applyLoadout`, `angleDiff`, `time.Time`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `Hub`, `abilities_test.go`, `RoundState`, `Arena`, `NewHub`, `models.go`, `balance.go`, `applyLoadout`, `testing.T`, `angleDiff`, `time.Time`, `profileFor`, `mustArena`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ACTIONS`, `$app`, `auditState` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._