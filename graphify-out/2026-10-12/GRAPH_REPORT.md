# Graph Report - gun-game  (2026-10-07)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1583 nodes · 5225 edges · 88 communities (66 shown, 22 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1343 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- app.js
- withDB
- admin_auth.go
- handlers_auth.go
- build_arena.py
- testing.T
- missions.go
- Hub
- matchmaking.go
- models.go
- Player
- demon_test.go
- patch_scenes.py
- LoadArena
- StoreBillingPlugin
- balance.go
- bot_sense_test.go
- RoundState
- context.Context
- build_rig.py
- Arena
- skins.go
- RewardedAdsPlugin
- missions_test.go
- WeaponStatsFor
- Row Sheet UI Asset Preview Page
- Hub
- mustArena
- NewHub
- time.Time
- handlers_chat.go
- abilities_test.go
- .FindPath
- PlayerModel
- applyLoadout
- MyketBillingPlugin
- handlers_leaderboard.go
- Hub
- android.content.Intent
- android.os.Bundle
- angleDiff
- normalize_skin.py
- gameModeByID
- adRewardClaimHandler
- deform_check.py
- MessageModel
- time.Duration
- make_wind_swirls.py
- .onReceive
- BazaarBillingPlugin
- handlers_gift_codes.go
- SeedCurrencyPacks
- dependencies
- arm_angles.py
- solve
- parseWSMessage
- prepare_chat_emojis.py
- Mode
- strip_white_bg.py
- sweep_sniper.py
- .getPluginSignals
- layout_check.py
- scan_arms.py
- iap_billing/build.sh
- rewarded_ads/build.sh
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- make_leaf_textures.py
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- SignalInfo
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Hub
- BotRuntime
- Hub
- Arena
- IabService
- Intent
- Override
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
- `getCharacterHealth()` --calls--> `CharacterStats()`  [INFERRED]
  gun_game_server/hub.go → gun_game_server/balance.go
- `checkAndUnlockAchievements()` --calls--> `col()`  [INFERRED]
  gun_game_server/achievements.go → gun_game_server/db.go
- `loadAchievementDefs()` --calls--> `col()`  [INFERRED]
  gun_game_server/achievements.go → gun_game_server/db.go
- `persistProfileStats()` --calls--> `col()`  [INFERRED]
  gun_game_server/achievements.go → gun_game_server/db.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (88 total, 22 thin omitted)

### Community 0 - "col"
Cohesion: 0.05
Nodes (193): currencyPack, go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo.Collection, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom() (+185 more)

### Community 1 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 2 - "withDB"
Cohesion: 0.06
Nodes (68): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray() (+60 more)

### Community 3 - "admin_auth.go"
Cohesion: 0.06
Nodes (60): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders() (+52 more)

### Community 4 - "handlers_auth.go"
Cohesion: 0.08
Nodes (57): guardStatus(), seedAuthPlayer(), TestProfileStatsFromRound(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody() (+49 more)

### Community 5 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 6 - "testing.T"
Cohesion: 0.09
Nodes (35): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget() (+27 more)

### Community 7 - "missions.go"
Cohesion: 0.14
Nodes (29): DailyMissionDef, buildSeasonPassResponse(), persistMatchMissions(), MatchParticipant, MissionDifficulty, MissionMetric, applyMatchToMissions(), applyMatchToSeasonStats() (+21 more)

### Community 8 - "Hub"
Cohesion: 0.11
Nodes (18): BotRuntime, github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), Hub, equippedFor(), getCharacterHealth(), NotifyEveryone() (+10 more)

### Community 9 - "matchmaking.go"
Cohesion: 0.08
Nodes (53): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), keysOf(), loadBotsNear(), makeBot(), makeBotName() (+45 more)

### Community 10 - "models.go"
Cohesion: 0.08
Nodes (32): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanJoinRequestModel (+24 more)

### Community 11 - "Player"
Cohesion: 0.14
Nodes (16): Arena, laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), BotRuntime (+8 more)

### Community 12 - "demon_test.go"
Cohesion: 0.14
Nodes (22): Arena, newDemon(), absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen() (+14 more)

### Community 13 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 14 - "LoadArena"
Cohesion: 0.15
Nodes (26): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), addPlayer(), containsStr(), Hub, keysOfPlayers(), TestBotTargetsOnlyEnemiesInItsOwnMatch() (+18 more)

### Community 15 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (3): Intent, StoreBillingPlugin, ServiceConnection

### Community 16 - "balance.go"
Cohesion: 0.24
Nodes (14): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), round2(), round3(), SeedCharacterStats(), shopCharacterRatings() (+6 more)

### Community 17 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 18 - "RoundState"
Cohesion: 0.16
Nodes (4): Hub, DemonState, Hub, RoundState

### Community 19 - "context.Context"
Cohesion: 0.19
Nodes (21): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, seedAchievements(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase() (+13 more)

### Community 20 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 21 - "Arena"
Cohesion: 0.16
Nodes (8): clampF(), Arena, MapNameForMode(), parseArena(), arenaFile, Room, Arena, hashString()

### Community 22 - "skins.go"
Cohesion: 0.18
Nodes (20): MaxLevelOf(), SkinDef, SkinEquipRequest, activeSkin(), allCharacterIDs(), characterLevel(), characterUpgradeView(), combatSummary() (+12 more)

### Community 23 - "RewardedAdsPlugin"
Cohesion: 0.15
Nodes (9): android.content.ServiceConnection, android.os.Handler, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.plugin.GodotPlugin, org.godotengine.godot.plugin.SignalInfo (+1 more)

### Community 24 - "missions_test.go"
Cohesion: 0.11
Nodes (27): DailyBonusTier, DailyMissionDoc, buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), dailyBonusTierByNeed(), loadOrCreateDailyMissions(), missionDayEnd() (+19 more)

### Community 25 - "WeaponStatsFor"
Cohesion: 0.16
Nodes (19): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), fireRateDamageComp(), fireRateMult(), shopWeaponRatings(), TestCombinedTurnRateStaysInRange(), TestFireConeStaysUsable() (+11 more)

### Community 26 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 27 - "Hub"
Cohesion: 0.19
Nodes (8): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage(), refreshAbilityTimers(), segmentHitsCircle()

### Community 28 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 29 - "NewHub"
Cohesion: 0.33
Nodes (13): NewHub(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestOnlyTheWinningTeamWinsANormalRound() (+5 more)

### Community 30 - "time.Time"
Cohesion: 0.18
Nodes (21): time.Time, ClanMember, GoogleAuthPending, RecentMatch, createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards() (+13 more)

### Community 31 - "handlers_chat.go"
Cohesion: 0.23
Nodes (17): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+9 more)

### Community 32 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 33 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 34 - "PlayerModel"
Cohesion: 0.17
Nodes (15): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement(), persistProfileStats(), TestNextAchievementPicksClosestLocked(), buildSeasonCupsResponse() (+7 more)

### Community 35 - "applyLoadout"
Cohesion: 0.29
Nodes (13): TestBombStockIsThreePerMatch(), magazineFor(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped() (+5 more)

### Community 36 - "MyketBillingPlugin"
Cohesion: 0.20
Nodes (3): Override, MyketBillingPlugin, org.godotengine.godot.Godot

### Community 37 - "handlers_leaderboard.go"
Cohesion: 0.25
Nodes (13): go.mongodb.org/mongo-driver/bson.M, cityPointsRow, cityLeaderboardEntry(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard() (+5 more)

### Community 38 - "Hub"
Cohesion: 0.26
Nodes (5): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta()

### Community 39 - "android.content.Intent"
Cohesion: 0.29
Nodes (5): android.app.Activity, android.content.Intent, BillingProxyActivity, Intent, Override

### Community 40 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 41 - "angleDiff"
Cohesion: 0.36
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), BotRuntime, angleDiff() (+3 more)

### Community 42 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 43 - "gameModeByID"
Cohesion: 0.31
Nodes (8): defaultGameModes(), gameModeByID(), loadGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore(), GameModeDef, TestRevengeIsOneVersusOne()

### Community 44 - "adRewardClaimHandler"
Cohesion: 0.43
Nodes (7): adRewardDay, adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adTokenRewarded(), missionDayKey()

### Community 45 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 46 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 47 - "time.Duration"
Cohesion: 0.33
Nodes (5): time.Duration, Arena, spawnShieldFor(), ModeOfMatch(), RoundRules

### Community 48 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 49 - ".onReceive"
Cohesion: 0.38
Nodes (4): android.content.BroadcastReceiver, android.content.Context, BillingBroadcastReceiver, Override

### Community 51 - "handlers_gift_codes.go"
Cohesion: 0.29
Nodes (8): sync.Mutex, createGiftCodeRequest, GiftCode, giftFailLimiter, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 52 - "SeedCurrencyPacks"
Cohesion: 0.48
Nodes (4): currencyPack, findCurrencyPack(), SeedCurrencyPacks(), TestSeedKeepsDatabaseDiscount()

### Community 53 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 54 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 55 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 56 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 57 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 58 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 59 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 60 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **71 isolated node(s):** `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonPassBuyBody`, `SeasonPassClaimBody` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **22 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `PlayerModel`, `admin_auth.go`, `handlers_auth.go`, `withDB`, `handlers_leaderboard.go`, `missions.go`, `Hub`, `matchmaking.go`, `gameModeByID`, `adRewardClaimHandler`, `balance.go`, `context.Context`, `handlers_gift_codes.go`, `SeedCurrencyPacks`, `skins.go`, `missions_test.go`, `time.Time`, `handlers_chat.go`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `col`, `withDB`, `handlers_auth.go`, `handlers_leaderboard.go`, `missions.go`, `matchmaking.go`, `models.go`, `adRewardClaimHandler`, `MessageModel`, `skins.go`, `time.Time`, `handlers_chat.go`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `applyLoadout`, `angleDiff`, `Player`, `parseWSMessage`, `NewHub`, `time.Time`?**
  _High betweenness centrality (0.032) - this node is a cross-community bridge._
- **Are the 175 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 175 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.05252889821001805 - nodes in this community are weakly interconnected._