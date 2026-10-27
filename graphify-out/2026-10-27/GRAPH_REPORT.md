# Graph Report - gun-game  (2026-10-27)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1700 nodes · 5633 edges · 99 communities (83 shown, 16 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 1421 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b8b80dcd`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- app.js
- col
- admin_auth.go
- matchmaking.go
- net/http.Request
- Hub
- build_arena.py
- handlers_auth.go
- testing.T
- CharacterStats
- Player
- handlers_clan.go
- skins.go
- models.go
- patch_scenes.py
- org.godotengine.godot.plugin.UsedByGodot
- bot_sense_test.go
- withDB
- RoundState
- StoreBillingPlugin
- Hub
- build_rig.py
- context.Context
- demon_test.go
- addPlayer
- handlers_iap.go
- seasonCupDefs
- Hub
- Row Sheet UI Asset Preview Page
- LoadArena
- mustArena
- go.mongodb.org/mongo-driver/bson.M
- PlayerModel
- weekly_rewards.go
- handlers_chat.go
- reconnect_test.go
- .FindPath
- missions_test.go
- Hub
- abilities_test.go
- Hub
- NewHub
- makeBot
- Arena
- android.content.Intent
- buildSeasonPassResponse
- applyMatchToSeasonStats
- android.os.Bundle
- applyLoadout
- handlers_missions.go
- missions.go
- BazaarBillingPlugin
- MyketBillingPlugin
- checkAndUnlockAchievements
- angleDiff
- BillingProxyActivity
- normalize_skin.py
- lucky_box.go
- time.Time
- deform_check.py
- time.Duration
- MessageModel
- adRewardClaimHandler
- .teamRoomsFor
- googleClaims
- seedClaimPlayer
- findGemPackByProduct
- make_wind_swirls.py
- handlers_gift_codes.go
- defaultGameModes
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
- BotRuntime
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 186 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `NewHub()` - 69 edges
5. `enableCORS()` - 68 edges
6. `Hub` - 67 edges
7. `PlayerModel` - 59 edges
8. `getPlayerByUsername()` - 54 edges
9. `Player` - 49 edges
10. `h()` - 48 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `upgradeCharacterHandler()` --calls--> `jsonResponse()`  [INFERRED]
  gun_game_server/skins.go → gun_game_server/handlers.go
- `claimSeasonCupHandler()` --calls--> `jsonResponse()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/handlers.go
- `claimSeasonCupHandler()` --calls--> `seasonXPOf()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/handlers_leaderboard.go
- `claimSeasonCupHandler()` --calls--> `currentSeasonCups()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/season_cups.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (99 total, 16 thin omitted)

### Community 0 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 1 - "col"
Cohesion: 0.10
Nodes (77): go.mongodb.org/mongo-driver/mongo.Collection, net/http.ResponseWriter, resolvePlayers(), adminFindPlayer(), col(), getGameModesHandler(), selectGameModeHandler(), adRewardStatusHandler() (+69 more)

### Community 2 - "admin_auth.go"
Cohesion: 0.05
Nodes (61): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled(), adminSecurityHeaders() (+53 more)

### Community 3 - "matchmaking.go"
Cohesion: 0.08
Nodes (54): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, myRankCard(), formMatchLocked(), matchmakingStatusHandler(), peersOfLocked() (+46 more)

### Community 4 - "net/http.Request"
Cohesion: 0.13
Nodes (53): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, net/http.Request, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), adminPage() (+45 more)

### Community 5 - "Hub"
Cohesion: 0.10
Nodes (17): github.com/gorilla/websocket.Conn, sync/atomic.Int64, Client, SetPlayerOnline(), allowPaced(), equippedFor(), Hub, Hub (+9 more)

### Community 6 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 7 - "handlers_auth.go"
Cohesion: 0.12
Nodes (44): TestProtectedAccountFlow(), authProbe, googleConfig, googleResult, googleStartBody, actingUsernames(), applyGoogleIdentity(), authGuard() (+36 more)

### Community 8 - "testing.T"
Cohesion: 0.08
Nodes (40): testing.T, nextAchievement(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestAuthGuardPassesThroughWithoutDatabase(), TestBearerToken(), TestGoogleClaimsValidation() (+32 more)

### Community 9 - "CharacterStats"
Cohesion: 0.08
Nodes (38): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), magazineFor(), shopRating(), TestNewGameplayHooksStayModerate(), TestNoLevelOneLoadoutOneShotsAnyone(), TestPipsRespectRarityRange() (+30 more)

### Community 10 - "Player"
Cohesion: 0.13
Nodes (18): laserSegment(), arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, turnStep() (+10 more)

### Community 11 - "handlers_clan.go"
Cohesion: 0.19
Nodes (32): adminClanKickHandler(), disbandClan(), ClanModel, newID(), clanLeaderInfo(), clanMemberRole(), clanRowLess(), clanSummary() (+24 more)

### Community 12 - "skins.go"
Cohesion: 0.12
Nodes (29): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+21 more)

### Community 13 - "models.go"
Cohesion: 0.08
Nodes (27): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+19 more)

### Community 14 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 15 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 16 - "bot_sense_test.go"
Cohesion: 0.15
Nodes (25): Hub, Player, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks() (+17 more)

### Community 17 - "withDB"
Cohesion: 0.22
Nodes (23): ApplyMatchOutcome(), ApplyMatchResult(), gameModeByID(), loadGameModes(), lossCoinsOf(), GameModeDef, TestIAPVerifyWithSignedReceipt(), TestBuyItemWorksWithNullOwnedArrays() (+15 more)

### Community 18 - "RoundState"
Cohesion: 0.19
Nodes (5): DemonState, Hub, RoundState, LiveObjective, MatchOutcome

### Community 19 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 20 - "Hub"
Cohesion: 0.17
Nodes (6): awayState, inboxItem, MatchOf(), awayKey(), Hub, inMatchmaking()

### Community 21 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 22 - "context.Context"
Cohesion: 0.20
Nodes (20): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, seedAchievements(), catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase() (+12 more)

### Community 23 - "demon_test.go"
Cohesion: 0.16
Nodes (19): Arena, newDemon(), absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen() (+11 more)

### Community 24 - "addPlayer"
Cohesion: 0.15
Nodes (20): TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored(), TestEndingOldRoundSparesThingsNowInAnotherMatch(), TestNoHitsOnOrByDeadPlayers(), TestRapidMoveSpamIsSpeedCapped(), TestRepeatedArenaJoinKeepsLivePlayerState() (+12 more)

### Community 25 - "handlers_iap.go"
Cohesion: 0.17
Nodes (18): crypto/rsa.PrivateKey, crypto/rsa.PublicKey, storeAPIConfigured(), verifyPurchase(), verifyStorePurchase(), envOr(), iapPackageName(), storePublicKey() (+10 more)

### Community 26 - "seasonCupDefs"
Cohesion: 0.21
Nodes (19): net/http/httptest.ResponseRecorder, seasonCupCount(), defaultSeasonCups(), fallbackSeasonCups(), invalidateSeasonCupCache(), seasonCupDefs(), seasonCupID(), seasonCupThresholds() (+11 more)

### Community 27 - "Hub"
Cohesion: 0.17
Nodes (9): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage(), refreshAbilityTimers(), segmentHitsCircle() (+1 more)

### Community 28 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 29 - "LoadArena"
Cohesion: 0.18
Nodes (19): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), TestNoFriendlyFireAndNoCrossMatchFire(), Hub, newRevengeRound() (+11 more)

### Community 30 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 31 - "go.mongodb.org/mongo-driver/bson.M"
Cohesion: 0.18
Nodes (18): go.mongodb.org/mongo-driver/bson.M, fanOutMessage(), adminDashboardHandler(), adminOnlineHandler(), adminServerHandler(), dailyCounts(), Hub, humans() (+10 more)

### Community 32 - "PlayerModel"
Cohesion: 0.21
Nodes (18): cityPointsRow, buildSeasonCupsResponse(), cityLeaderboardEntry(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard() (+10 more)

### Community 33 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 34 - "handlers_chat.go"
Cohesion: 0.23
Nodes (17): ChatMessageModel, allowChatSend(), broadcastChatMessage(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread() (+9 more)

### Community 35 - "reconnect_test.go"
Cohesion: 0.41
Nodes (17): arenaPlayer(), connectFake(), drain(), dropFake(), firstOf(), Hub, rejoinFake(), TestAwayBudgetIsPerMatch() (+9 more)

### Community 36 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 37 - "missions_test.go"
Cohesion: 0.17
Nodes (16): DailyMissionDoc, buildDailyBonusView(), loadOrCreateDailyMissions(), missionSeed(), pickDailyMissions(), repairMissionStates(), TestBuildDailyBonusViewDoesNotMutateTable(), TestBuildDailyBonusViewStates() (+8 more)

### Community 38 - "Hub"
Cohesion: 0.25
Nodes (3): BotRuntime, Hub, DemonState

### Community 39 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 40 - "Hub"
Cohesion: 0.22
Nodes (7): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta(), MissionMetric, SeasonChallenge

### Community 41 - "NewHub"
Cohesion: 0.29
Nodes (15): TestAssistCreditedToRecentTeammateDamager(), NewHub(), Hub, newRound(), TestADrawIsNotAWin(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestEliminationTimeoutGoesToTheSurvivors() (+7 more)

### Community 42 - "makeBot"
Cohesion: 0.22
Nodes (14): math/rand.Rand, botSkillFor(), keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots() (+6 more)

### Community 43 - "Arena"
Cohesion: 0.27
Nodes (4): Arena, clampF(), arenaFile, Room

### Community 44 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 45 - "buildSeasonPassResponse"
Cohesion: 0.20
Nodes (13): buildSeasonPassResponse(), buildSeasonChallengeView(), currentSeasonPass(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestCurrentSeasonPassNormalisesNewFields() (+5 more)

### Community 46 - "applyMatchToSeasonStats"
Cohesion: 0.22
Nodes (12): persistMatchMissions(), MatchParticipant, addSeasonPassXP(), applyMatchToMissions(), applyMatchToSeasonStats(), carryPlaySeconds(), ensureSeasonPass(), incSeasonPass() (+4 more)

### Community 47 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 48 - "applyLoadout"
Cohesion: 0.31
Nodes (11): TestBombStockIsThreePerMatch(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput() (+3 more)

### Community 49 - "handlers_missions.go"
Cohesion: 0.17
Nodes (12): DailyBonusClaimBody, buildMissionsResponse(), MissionClaimBody, dailyBonusMaxNeed(), missionDayEnd(), missionSecondsLeft(), TestDailyBonusTiersAreAscending(), TestMissionDayBoundary() (+4 more)

### Community 50 - "missions.go"
Cohesion: 0.29
Nodes (12): DailyBonusTier, DailyMissionDef, MissionDifficulty, dailyBonusTierByNeed(), SeasonPassLadder(), SeasonPassPremiumLadder(), seasonPassPremiumReward(), seasonPassReward() (+4 more)

### Community 53 - "checkAndUnlockAchievements"
Cohesion: 0.29
Nodes (10): achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), persistProfileStats(), guardStatus(), seedAuthPlayer(), TestProfileStatsFromRound() (+2 more)

### Community 54 - "angleDiff"
Cohesion: 0.39
Nodes (10): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), angleDiff(), clampRotation() (+2 more)

### Community 55 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 56 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 57 - "lucky_box.go"
Cohesion: 0.42
Nodes (8): drawLuckyBox(), luckyBoxChoices(), luckyBoxInfo(), luckyBoxPool(), TestLuckyBoxDrawIsSpreadAndWeighted(), TestLuckyBoxHasNoLegendOrFreebies(), TestLuckyBoxSkipsOwned(), luckyBoxEntry

### Community 58 - "time.Time"
Cohesion: 0.28
Nodes (8): sync.Mutex, time.Time, ClanMember, giftFailLimiter, GoogleAuthPending, RecentMatch, SupportMessageModel, SupportReply

### Community 59 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 60 - "time.Duration"
Cohesion: 0.36
Nodes (7): time.Duration, TestDemonHuntRules(), rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules

### Community 61 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 62 - "adRewardClaimHandler"
Cohesion: 0.43
Nodes (7): adRewardDay, adRewardRequest, adAlreadyCredited(), adRewardClaimHandler(), adRewardStatus(), adTokenRewarded(), missionDayKey()

### Community 63 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 64 - "googleClaims"
Cohesion: 0.43
Nodes (7): TestClaimsFromTokenInfoStrings(), googleClaims, asString(), claimsFromMap(), exchangeGoogleCode(), parseIDTokenPayload(), verifyGoogleIDToken()

### Community 65 - "seedClaimPlayer"
Cohesion: 0.61
Nodes (7): coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull()

### Community 66 - "findGemPackByProduct"
Cohesion: 0.43
Nodes (5): currencyPack, findCurrencyPack(), findGemPackByProduct(), SeedCurrencyPacks(), TestSeedKeepsDatabaseDiscount()

### Community 67 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 68 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 69 - "defaultGameModes"
Cohesion: 0.38
Nodes (6): defaultGameModes(), seedGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore(), TestRevengeIsOneVersusOne()

### Community 70 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 71 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 72 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 73 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 74 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 75 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 76 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 77 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 78 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **71 isolated node(s):** `ACTIONS`, `$app`, `auditState`, `CHANNEL`, `chatState` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `admin_auth.go`, `net/http.Request`, `Hub`, `handlers_auth.go`, `CharacterStats`, `handlers_clan.go`, `skins.go`, `withDB`, `context.Context`, `seasonCupDefs`, `go.mongodb.org/mongo-driver/bson.M`, `PlayerModel`, `weekly_rewards.go`, `handlers_chat.go`, `missions_test.go`, `makeBot`, `applyMatchToSeasonStats`, `checkAndUnlockAchievements`, `adRewardClaimHandler`, `seedClaimPlayer`, `findGemPackByProduct`, `handlers_gift_codes.go`, `defaultGameModes`?**
  _High betweenness centrality (0.124) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `CharacterStats`, `Player`, `NewHub`, `handlers_clan.go`, `parseWSMessage`, `applyLoadout`, `RoundState`, `Hub`, `angleDiff`, `time.Time`, `time.Duration`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `col`, `handlers_chat.go`, `matchmaking.go`, `net/http.Request`, `seasonCupDefs`, `handlers_auth.go`, `makeBot`, `handlers_clan.go`, `skins.go`, `buildSeasonPassResponse`, `models.go`, `withDB`, `checkAndUnlockAchievements`, `time.Time`, `MessageModel`, `adRewardClaimHandler`?**
  _High betweenness centrality (0.034) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ACTIONS`, `$app`, `auditState` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `app.js` be split into smaller, more focused modules?**
  _Cohesion score 0.12134831460674157 - nodes in this community are weakly interconnected._