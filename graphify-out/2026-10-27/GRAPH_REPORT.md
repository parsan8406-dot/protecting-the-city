# Graph Report - gun-game  (2026-10-27)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1654 nodes · 5466 edges · 96 communities (78 shown, 18 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 1392 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `3dc4acb4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- net/http.Request
- context.Context
- app.js
- admin_auth.go
- withDB
- handlers_auth.go
- build_arena.py
- bots_test.go
- mm_window_test.go
- Hub
- models.go
- NewHub
- CharacterStats
- PlayerModel
- Player
- RoundState
- patch_scenes.py
- org.godotengine.godot.plugin.UsedByGodot
- testing.T
- missions.go
- StoreBillingPlugin
- missions_test.go
- build_rig.py
- Row Sheet UI Asset Preview Page
- Hub
- mustArena
- demon_test.go
- net/http.ResponseWriter
- abilities_test.go
- applyLoadout
- Arena
- .FindPath
- LoadArena
- Hub
- matchmaking.go
- android.content.Intent
- android.os.Bundle
- angleDiff
- handlers_clan.go
- BazaarBillingPlugin
- MyketBillingPlugin
- mm_backfill.go
- Hub
- BillingProxyActivity
- handlers_gift_codes.go
- seasonPassXPRequired
- normalize_skin.py
- deform_check.py
- time.Time
- .teamRoomsFor
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
- countOf
- col
- seasonCupDefs
- handlers_chat.go
- getPlayerByID
- TestIAPVerifyWithSignedReceipt
- handlers_iap.go
- rankFromTrophies
- profileFor
- lucky_box.go
- MessageModel
- pathArena
- broadcastChatMessage
- claimSeasonCupHandler

## God Nodes (most connected - your core abstractions)
1. `col()` - 186 edges
2. `httpError()` - 112 edges
3. `jsonResponse()` - 109 edges
4. `enableCORS()` - 68 edges
5. `Hub` - 63 edges
6. `NewHub()` - 60 edges
7. `PlayerModel` - 59 edges
8. `getPlayerByUsername()` - 54 edges
9. `h()` - 48 edges
10. `Player` - 45 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `getPlayerHandler()` --calls--> `equippedSkinsView()`  [INFERRED]
  gun_game_server/handlers.go → gun_game_server/skins.go
- `equipSkinHandler()` --calls--> `col()`  [INFERRED]
  gun_game_server/skins.go → gun_game_server/db.go
- `equipSkinHandler()` --calls--> `jsonResponse()`  [INFERRED]
  gun_game_server/skins.go → gun_game_server/handlers.go
- `equipSkinHandler()` --calls--> `getPlayerByID()`  [INFERRED]
  gun_game_server/skins.go → gun_game_server/handlers_social.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (96 total, 18 thin omitted)

### Community 0 - "net/http.Request"
Cohesion: 0.13
Nodes (49): net/http.Request, adminDecode(), adminFrom(), adminLogoutHandler(), adminMeHandler(), audit(), writeAudit(), adminChatDeleteHandler() (+41 more)

### Community 1 - "context.Context"
Cohesion: 0.05
Nodes (72): context.Context, go.mongodb.org/mongo-driver/bson.M, go.mongodb.org/mongo-driver/mongo.IndexModel, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), loadAchievementDefs(), nextAchievement() (+64 more)

### Community 2 - "app.js"
Cohesion: 0.12
Nodes (88): ACTIONS, add(), ago(), api(), $app, auditState, auditTable(), avatar() (+80 more)

### Community 3 - "admin_auth.go"
Cohesion: 0.05
Nodes (61): bufio.Scanner, net/http.HandlerFunc, net/http.ServeMux, sync.Mutex, adminAPI(), adminLoginHandler(), adminMePayload(), adminPanelEnabled() (+53 more)

### Community 4 - "withDB"
Cohesion: 0.23
Nodes (21): coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull(), TestBuyItemWorksWithNullOwnedArrays() (+13 more)

### Community 5 - "handlers_auth.go"
Cohesion: 0.08
Nodes (60): guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestAuthGuardPassesThroughWithoutDatabase() (+52 more)

### Community 6 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 7 - "bots_test.go"
Cohesion: 0.14
Nodes (20): math/rand.Rand, botSkillFor(), gentleBotLoadout(), keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear() (+12 more)

### Community 8 - "mm_window_test.go"
Cohesion: 0.53
Nodes (12): enqueue(), formNow(), resetQueues(), TestClosestPeersAreChosen(), TestLonelyAnchorDoesNotBlockOthers(), TestMatchRespectsTrophyWindow(), TestOpenWindowStillPrefersClosest(), TestSnakeDraftBalancesTeams() (+4 more)

### Community 9 - "Hub"
Cohesion: 0.12
Nodes (12): github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), allowPaced(), equippedFor(), Hub, Hub, loadoutOf() (+4 more)

### Community 10 - "models.go"
Cohesion: 0.08
Nodes (31): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+23 more)

### Community 11 - "NewHub"
Cohesion: 0.12
Nodes (36): TestAbandonedRoundClosesImmediately(), TestAngleDiffHugeInputTerminates(), TestAssistCreditedToRecentTeammateDamager(), TestBigMoveCannotTunnelThroughThinWall(), TestDroppedClientIsCleanedUpAndIgnored(), TestEndingOldRoundSparesThingsNowInAnotherMatch(), TestNoHitsOnOrByDeadPlayers(), TestRapidMoveSpamIsSpeedCapped() (+28 more)

### Community 12 - "CharacterStats"
Cohesion: 0.11
Nodes (28): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), CharacterStats(), magazineFor(), TestNewGameplayHooksStayModerate(), TestResolvedStatsStayInSaneBounds(), TestUnknownCharacterFallsBackToBalanced(), clampUnit() (+20 more)

### Community 13 - "PlayerModel"
Cohesion: 0.10
Nodes (35): avgPip(), characterCombatDoc(), CharacterStatsAtLevel(), levelFactor(), MaxLevelOf(), round2(), round3(), SeedCharacterStats() (+27 more)

### Community 14 - "Player"
Cohesion: 0.16
Nodes (14): arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, turnStep(), BotRuntime (+6 more)

### Community 15 - "RoundState"
Cohesion: 0.15
Nodes (9): DemonState, time.Duration, Hub, spawnShieldFor(), MatchOf(), ModeOfMatch(), RoundRules, RoundState (+1 more)

### Community 16 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 17 - "org.godotengine.godot.plugin.UsedByGodot"
Cohesion: 0.11
Nodes (11): android.content.ServiceConnection, android.os.Handler, SignalInfo, Override, SignalInfo, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot (+3 more)

### Community 18 - "testing.T"
Cohesion: 0.10
Nodes (33): testing.T, shopRating(), TestNoLevelOneLoadoutOneShotsAnyone(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestSameRaritySharesSamePipBudget(), TestShopRatingGapStaysSmallAcrossRarities() (+25 more)

### Community 19 - "missions.go"
Cohesion: 0.19
Nodes (20): DailyMissionDef, persistMatchMissions(), MissionDifficulty, MissionMetric, applyMatchToMissions(), applyMatchToSeasonStats(), carryPlaySeconds(), ensureSeasonPass() (+12 more)

### Community 20 - "StoreBillingPlugin"
Cohesion: 0.19
Nodes (4): Intent, Override, StoreBillingPlugin, ServiceConnection

### Community 21 - "missions_test.go"
Cohesion: 0.12
Nodes (22): DailyBonusTier, buildMissionsResponse(), buildDailyBonusView(), dailyBonusMaxNeed(), dailyBonusTierByNeed(), missionDayEnd(), missionSecondsLeft(), missionSeed() (+14 more)

### Community 22 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 23 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 24 - "Hub"
Cohesion: 0.18
Nodes (9): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), refreshAbilityTimers() (+1 more)

### Community 25 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 26 - "demon_test.go"
Cohesion: 0.18
Nodes (18): absF(), Arena, Hub, mustBanishArena(), newDemonRound(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates(), TestDemonDiesWithEqualDamageIsADraw() (+10 more)

### Community 27 - "net/http.ResponseWriter"
Cohesion: 0.16
Nodes (34): go.mongodb.org/mongo-driver/mongo.Collection, net/http.ResponseWriter, getGameModesHandler(), selectGameModeHandler(), adRewardStatusHandler(), googleAuthPollHandler(), buyItemHandler(), getClansHandler() (+26 more)

### Community 28 - "abilities_test.go"
Cohesion: 0.28
Nodes (16): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+8 more)

### Community 29 - "applyLoadout"
Cohesion: 0.40
Nodes (10): TestBombStockIsThreePerMatch(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput() (+2 more)

### Community 30 - "Arena"
Cohesion: 0.22
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 31 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 32 - "LoadArena"
Cohesion: 0.25
Nodes (15): ArenaForMode(), LoadArena(), Hub, newRevengeRound(), TestAttackingEndsYourOwnShield(), TestJoinRoundIsIdempotent(), TestLateJoinerStillRespawns(), TestRespawnSpawnIsSafeButNotFar() (+7 more)

### Community 33 - "Hub"
Cohesion: 0.19
Nodes (6): Arena, BotRuntime, Hub, newDemon(), TestNoSpawnSitsOnTheDemon(), DemonState

### Community 34 - "matchmaking.go"
Cohesion: 0.30
Nodes (13): TestNewbieMatchGetsGentleBots(), formMatchLocked(), matchmakingStatusHandler(), peersOfLocked(), trophyGap(), tryFormMatchLocked(), gentleForNewbie(), maybeBackfill() (+5 more)

### Community 35 - "android.content.Intent"
Cohesion: 0.22
Nodes (5): android.content.BroadcastReceiver, android.content.Context, android.content.Intent, BillingBroadcastReceiver, Override

### Community 36 - "android.os.Bundle"
Cohesion: 0.31
Nodes (4): android.os.Bundle, android.os.IBinder, android.os.Parcel, IabService

### Community 37 - "angleDiff"
Cohesion: 0.35
Nodes (11): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), TestHitActionIsRateLimited(), angleDiff() (+3 more)

### Community 38 - "handlers_clan.go"
Cohesion: 0.17
Nodes (34): adminClanHandler(), adminClanKickHandler(), disbandClan(), ClanMember, ClanModel, clanLeaderInfo(), clanMemberRole(), clanRowLess() (+26 more)

### Community 41 - "mm_backfill.go"
Cohesion: 0.21
Nodes (18): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, removeFromQueueLocked(), botsInMatchOf(), busyNamesLocked(), otherHumansPending() (+10 more)

### Community 42 - "Hub"
Cohesion: 0.16
Nodes (10): minInt(), LiveObjective, buildObjectives(), Hub, liveDelta(), buildSeasonChallengeView(), currentSeasonPass(), TestCurrentSeasonPassNormalisesNewFields() (+2 more)

### Community 43 - "BillingProxyActivity"
Cohesion: 0.31
Nodes (4): android.app.Activity, BillingProxyActivity, Intent, Override

### Community 44 - "handlers_gift_codes.go"
Cohesion: 0.48
Nodes (6): createGiftCodeRequest, GiftCode, createGiftCode(), normalizeGiftCode(), randomGiftCode(), redeemGiftCodeRequest

### Community 45 - "seasonPassXPRequired"
Cohesion: 0.43
Nodes (7): seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestSeasonPassMaxLevelBarStaysFull(), TestSeasonPassProgress(), TestSeasonPassTotalMatchesProgress()

### Community 46 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 47 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 48 - "time.Time"
Cohesion: 0.17
Nodes (18): time.Time, adRewardDay, adRewardRequest, DailyMissionDoc, TestBanishArenaIsOpen(), giftFailLimiter, GoogleAuthPending, adAlreadyCredited() (+10 more)

### Community 49 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 50 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 51 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 52 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 53 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 54 - "parseWSMessage"
Cohesion: 0.60
Nodes (4): parseWSMessage(), TestParseWSMessageIgnoresServerOwnedFields(), TestParseWSMessageReadsBombDistance(), TestParseWSMessageReadsEveryClientField()

### Community 55 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 56 - "check_store_apk.sh"
Cohesion: 0.70
Nodes (4): bad(), ok(), check_store_apk.sh script, warn()

### Community 57 - "Mode"
Cohesion: 0.50
Nodes (4): Mode, BROADCAST, NONE, SERVICE

### Community 58 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 59 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 82 - "countOf"
Cohesion: 0.17
Nodes (24): go.mongodb.org/mongo-driver/bson.D, go.mongodb.org/mongo-driver/mongo/options.FindOptions, adminPage(), findPage(), adminCampaignsHandler(), adminSupportListHandler(), adminClansHandler(), adminPurchasesHandler() (+16 more)

### Community 83 - "col"
Cohesion: 0.21
Nodes (24): col(), getPlayerHandler(), claimAllMessagesHandler(), claimMessageRewardHandler(), claimOneMessage(), countUnreadMessages(), deleteMessageHandler(), getFriendsHandler() (+16 more)

### Community 84 - "seasonCupDefs"
Cohesion: 0.19
Nodes (21): net/http/httptest.ResponseRecorder, seasonCupCount(), PlayerSeasonCups, currentSeasonCups(), defaultSeasonCups(), fallbackSeasonCups(), invalidateSeasonCupCache(), seasonCupDefs() (+13 more)

### Community 85 - "handlers_chat.go"
Cohesion: 0.22
Nodes (21): ChatMessageModel, allowChatSend(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread(), fillLastMessage() (+13 more)

### Community 86 - "getPlayerByID"
Cohesion: 0.19
Nodes (18): DailyBonusClaimBody, buildSeasonPassResponse(), buySeasonPassHandler(), claimDailyBonusHandler(), claimDailyMissionHandler(), claimSeasonChallengeHandler(), claimSeasonPassHandler(), levelFromExperience() (+10 more)

### Community 87 - "TestIAPVerifyWithSignedReceipt"
Cohesion: 0.25
Nodes (11): crypto/rsa.PrivateKey, currencyPack, receipt(), TestIAPVerifyWithSignedReceipt(), TestSignedReceiptAcceptedAndForgeriesRejected(), testStore(), validFields(), findCurrencyPack() (+3 more)

### Community 88 - "handlers_iap.go"
Cohesion: 0.21
Nodes (13): crypto/rsa.PublicKey, storeAPIConfigured(), verifyPurchase(), verifyStorePurchase(), envOr(), iapPackageName(), storePublicKey(), TestBundledBazaarKeyParses() (+5 more)

### Community 89 - "rankFromTrophies"
Cohesion: 0.16
Nodes (12): myRankCard(), playerLeaderboardEntry(), rankFromTrophies(), rankViewOf(), tierIndexOf(), TestRankThemeTable(), PublicProfile, themeForPlayers() (+4 more)

### Community 90 - "profileFor"
Cohesion: 0.36
Nodes (11): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, Player, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam() (+3 more)

### Community 91 - "lucky_box.go"
Cohesion: 0.42
Nodes (8): drawLuckyBox(), luckyBoxChoices(), luckyBoxInfo(), luckyBoxPool(), TestLuckyBoxDrawIsSpreadAndWeighted(), TestLuckyBoxHasNoLegendOrFreebies(), TestLuckyBoxSkipsOwned(), luckyBoxEntry

### Community 92 - "MessageModel"
Cohesion: 0.25
Nodes (6): AdminCampaign, adminSendRequest, TestPersonalizeBroadcasts(), personalizeBroadcasts(), MessageModel, MessageReward

### Community 93 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 94 - "broadcastChatMessage"
Cohesion: 0.40
Nodes (5): broadcastChatMessage(), NotifyEveryone(), NotifyUsers(), queueNotify(), userMessage

### Community 95 - "claimSeasonCupHandler"
Cohesion: 0.53
Nodes (5): buildSeasonCupsResponse(), claimSeasonCupHandler(), getSeasonCupsHandler(), seasonXPOf(), SeasonCupClaimBody

## Knowledge Gaps
- **71 isolated node(s):** `SeasonCupClaimBody`, `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonPassBuyBody` (+66 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **18 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `net/http.Request`, `context.Context`, `admin_auth.go`, `withDB`, `handlers_auth.go`, `bots_test.go`, `Hub`, `CharacterStats`, `PlayerModel`, `missions.go`, `net/http.ResponseWriter`, `handlers_clan.go`, `handlers_gift_codes.go`, `time.Time`, `countOf`, `seasonCupDefs`, `handlers_chat.go`, `getPlayerByID`, `TestIAPVerifyWithSignedReceipt`, `claimSeasonCupHandler`?**
  _High betweenness centrality (0.092) - this node is a cross-community bridge._
- **Why does `RoundState` connect `RoundState` to `LoadArena`, `Hub`, `Hub`, `Hub`, `NewHub`, `time.Time`, `demon_test.go`?**
  _High betweenness centrality (0.041) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `PlayerModel` to `net/http.Request`, `context.Context`, `withDB`, `handlers_auth.go`, `handlers_clan.go`, `bots_test.go`, `Hub`, `models.go`, `time.Time`, `col`, `seasonCupDefs`, `handlers_chat.go`, `getPlayerByID`, `rankFromTrophies`, `net/http.ResponseWriter`, `MessageModel`, `broadcastChatMessage`, `claimSeasonCupHandler`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Are the 176 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 176 INFERRED edges - model-reasoned connections that need verification._
- **Are the 103 inferred relationships involving `httpError()` (e.g. with `adminAPI()` and `adminDecode()`) actually correct?**
  _`httpError()` has 103 INFERRED edges - model-reasoned connections that need verification._
- **What connects `SeasonCupClaimBody`, `DailyBonusClaimBody`, `MissionClaimBody` to the rest of the system?**
  _71 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `net/http.Request` be split into smaller, more focused modules?**
  _Cohesion score 0.1297134238310709 - nodes in this community are weakly interconnected._