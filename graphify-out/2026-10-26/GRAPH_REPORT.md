# Graph Report - gun-game  (2026-10-19)

## Corpus Check
- 131 files · ~372,266 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1643 nodes · 5452 edges · 84 communities (69 shown, 15 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 1391 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- time.Duration
- admin_auth.go
- withDB
- time.Time
- col
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
- bot_sense_test.go
- db.go
- PlayerModel
- build_rig.py
- org.godotengine.godot.plugin.UsedByGodot
- Hub
- testing.T
- Row Sheet UI Asset Preview Page
- Arena
- mustArena
- skins.go
- weekly_rewards.go
- abilities_test.go
- .FindPath
- handlers_clan.go
- TestIAPVerifyWithSignedReceipt
- MessageModel
- BillingProxyActivity
- android.os.Bundle
- android.content.Intent
- BazaarBillingPlugin
- MyketBillingPlugin
- normalize_skin.py
- angleDiff
- deform_check.py
- go.mongodb.org/mongo-driver/bson.M
- LoadArena
- make_wind_swirls.py
- missions_test.go
- handlers.go
- missions.go
- dependencies
- arm_angles.py
- solve
- Hub
- parseWSMessage
- prepare_chat_emojis.py
- check_store_apk.sh
- Mode
- Hub
- strip_white_bg.py
- sweep_sniper.py
- buildSeasonPassResponse
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
- handlers_gift_codes.go

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
- `TestRespawnRestoresFullKit()` --calls--> `bombStockKey()`  [INFERRED]
  gun_game_server/hub_hardening_test.go → gun_game_server/abilities.go
- `TestGuardBlocksShotsAndBombs()` --calls--> `isGuarded()`  [INFERRED]
  gun_game_server/abilities_test.go → gun_game_server/abilities.go
- `TestRespawnRestoresFullKit()` --calls--> `isGuarded()`  [INFERRED]
  gun_game_server/hub_hardening_test.go → gun_game_server/abilities.go
- `TestSegmentHitsCircle()` --calls--> `segmentHitsCircle()`  [INFERRED]
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

### Community 1 - "time.Duration"
Cohesion: 0.33
Nodes (5): time.Duration, Arena, spawnShieldFor(), ModeOfMatch(), RoundRules

### Community 2 - "admin_auth.go"
Cohesion: 0.06
Nodes (62): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminLogoutHandler(), adminMePayload(), adminPanelEnabled() (+54 more)

### Community 3 - "withDB"
Cohesion: 0.07
Nodes (62): net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull() (+54 more)

### Community 4 - "time.Time"
Cohesion: 0.12
Nodes (20): sync.Mutex, time.Time, AdminAuditEntry, adminLockState, adRewardDay, ClanMember, DailyMissionDoc, giftFailLimiter (+12 more)

### Community 5 - "col"
Cohesion: 0.10
Nodes (54): resolvePlayers(), DailyBonusClaimBody, col(), enableCORS(), getPlayerHandler(), iapVerifyHandler(), respondIAP(), buySeasonPassHandler() (+46 more)

### Community 6 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "Hub"
Cohesion: 0.11
Nodes (17): github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), allowPaced(), equippedFor(), BotRuntime, Hub, Hub (+9 more)

### Community 9 - "checkAndUnlockAchievements"
Cohesion: 0.36
Nodes (9): AchievementDef, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), persistProfileStats(), seedAchievements(), TestProfileStatsFromRound() (+1 more)

### Community 10 - "handlers_auth.go"
Cohesion: 0.07
Nodes (64): nextAchievement(), guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody() (+56 more)

### Community 11 - "matchmaking.go"
Cohesion: 0.08
Nodes (53): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), botSkillFor(), keysOf(), loadBotsNear(), makeBot() (+45 more)

### Community 12 - "demon_test.go"
Cohesion: 0.17
Nodes (20): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+12 more)

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
Cohesion: 0.14
Nodes (63): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, net/http.ResponseWriter, adminDecode(), adminFrom(), adminMeHandler(), adminPage() (+55 more)

### Community 17 - "models.go"
Cohesion: 0.07
Nodes (32): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanJoinRequestModel (+24 more)

### Community 18 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 19 - "NewHub"
Cohesion: 0.12
Nodes (36): Arena, TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored(), TestEndingOldRoundSparesThingsNowInAnotherMatch(), TestNoHitsOnOrByDeadPlayers() (+28 more)

### Community 20 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 21 - "context.Context"
Cohesion: 0.16
Nodes (30): context.Context, iapRow(), adminFindPlayer(), adminPlayerHandler(), findAll(), nonNilMatches(), ChatMessageModel, allowChatSend() (+22 more)

### Community 22 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 23 - "db.go"
Cohesion: 0.12
Nodes (22): go.mongodb.org/mongo-driver/mongo.IndexModel, catalogPrice, currencyPack, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+14 more)

### Community 24 - "PlayerModel"
Cohesion: 0.12
Nodes (32): cityPointsRow, ClanModel, getGameModesHandler(), clanLeaderInfo(), clanWorldRank(), enrichClanMembers(), buildSeasonCupsResponse(), claimSeasonCupHandler() (+24 more)

### Community 25 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 26 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 27 - "Hub"
Cohesion: 0.18
Nodes (8): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage(), refreshAbilityTimers(), segmentHitsCircle()

### Community 28 - "testing.T"
Cohesion: 0.09
Nodes (32): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestSameRaritySharesSamePipBudget(), TestShopRatingGapStaysSmallAcrossRarities() (+24 more)

### Community 29 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 30 - "Arena"
Cohesion: 0.15
Nodes (8): clampF(), Arena, MapNameForMode(), parseArena(), arenaFile, Room, Arena, hashString()

### Community 31 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 32 - "skins.go"
Cohesion: 0.06
Nodes (67): TestBombStockIsThreePerMatch(), TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor() (+59 more)

### Community 33 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 34 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 35 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 36 - "handlers_clan.go"
Cohesion: 0.22
Nodes (27): adminClanKickHandler(), disbandClan(), newID(), clanMemberRole(), clanRowLess(), clanSummary(), createClanHandler(), getClanByID() (+19 more)

### Community 37 - "TestIAPVerifyWithSignedReceipt"
Cohesion: 0.17
Nodes (19): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, storeAPIConfigured(), verifyPurchase(), verifyStorePurchase(), envOr(), iapPackageName(), storePublicKey() (+11 more)

### Community 38 - "MessageModel"
Cohesion: 0.33
Nodes (4): AdminCampaign, adminSendRequest, MessageModel, MessageReward

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
Cohesion: 0.44
Nodes (10): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), angleDiff(), clampRotation() (+2 more)

### Community 46 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 47 - "go.mongodb.org/mongo-driver/bson.M"
Cohesion: 0.23
Nodes (16): go.mongodb.org/mongo-driver/bson.M, fanOutMessage(), adminShopHandler(), adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), countOf(), dailyCounts() (+8 more)

### Community 48 - "LoadArena"
Cohesion: 0.19
Nodes (18): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), TestTeamsSpawnTogetherAndApart(), Hub, newRevengeRound(), TestAttackingEndsYourOwnShield(), TestJoinRoundIsIdempotent() (+10 more)

### Community 49 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 50 - "missions_test.go"
Cohesion: 0.11
Nodes (24): DailyBonusTier, buildDailyBonusView(), dailyBonusTierByNeed(), missionSeed(), pickDailyMissions(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel() (+16 more)

### Community 51 - "handlers.go"
Cohesion: 0.43
Nodes (7): go.mongodb.org/mongo-driver/mongo.Collection, buyItemHandler(), equipItemHandler(), handleCoinPackPurchase(), handleRegularItemPurchase(), respondPurchase(), isSkinID()

### Community 52 - "missions.go"
Cohesion: 0.24
Nodes (16): DailyMissionDef, persistMatchMissions(), MatchParticipant, MissionDifficulty, MissionMetric, applyMatchToMissions(), applyMatchToSeasonStats(), buildSeasonChallengeView() (+8 more)

### Community 53 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 54 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 55 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

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

### Community 61 - "Hub"
Cohesion: 0.23
Nodes (5): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta()

### Community 62 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 63 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 64 - "buildSeasonPassResponse"
Cohesion: 0.39
Nodes (9): buildSeasonPassResponse(), SeasonPassLadder(), SeasonPassPremiumLadder(), seasonPassPremiumReward(), seasonPassReward(), TestPremiumLadderBeatsFree(), TestSeasonPassRewardsAlwaysGiveSomething(), SeasonPassReward (+1 more)

### Community 94 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

## Knowledge Gaps
- **71 isolated node(s):** `build.sh script`, `NONE`, `SERVICE`, `BROADCAST`, `build.sh script` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `admin_auth.go`, `withDB`, `Hub`, `checkAndUnlockAchievements`, `handlers_auth.go`, `matchmaking.go`, `adRewardClaimHandler`, `net/http.ResponseWriter`, `context.Context`, `db.go`, `PlayerModel`, `skins.go`, `weekly_rewards.go`, `handlers_clan.go`, `TestIAPVerifyWithSignedReceipt`, `go.mongodb.org/mongo-driver/bson.M`, `handlers.go`, `missions.go`, `handlers_gift_codes.go`?**
  _High betweenness centrality (0.107) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `skins.go`, `time.Time`, `handlers_clan.go`, `matchmaking.go`, `Player`, `angleDiff`, `RoundState`, `NewHub`, `parseWSMessage`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `buildSeasonPassResponse`, `skins.go`, `withDB`, `handlers_clan.go`, `col`, `time.Time`, `checkAndUnlockAchievements`, `handlers_auth.go`, `matchmaking.go`, `adRewardClaimHandler`, `net/http.ResponseWriter`, `models.go`, `handlers.go`, `missions.go`, `context.Context`?**
  _High betweenness centrality (0.035) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `build.sh script`, `NONE`, `SERVICE` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._