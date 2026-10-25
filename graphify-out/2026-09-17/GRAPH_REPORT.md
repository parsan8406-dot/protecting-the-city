# Graph Report - gun-game  (2026-09-16)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1126 nodes · 3422 edges · 73 communities (54 shown, 19 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 887 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- context.Context
- applyLoadout
- matchmaking.go
- Hub
- build_arena.py
- LoadArena
- patch_scenes.py
- testing.T
- Player
- models.go
- bot_sense_test.go
- build_rig.py
- RoundState
- Hub
- Row Sheet UI Asset Preview Page
- Hub
- mustArena
- demon_test.go
- weekly_rewards.go
- time.Time
- .FindPath
- handlers_chat.go
- missions_test.go
- Hub
- abilities_test.go
- PlayerModel
- NewHub
- missions.go
- Arena
- distance
- angleDiff
- deform_check.py
- .teamRoomsFor
- googleClaims
- seedClaimPlayer
- buildMissionsResponse
- applyMatchToSeasonStats
- seasonPassXPRequired
- time.Duration
- dependencies
- arm_angles.py
- solve
- loadOrCreateDailyMissions
- prepare_chat_emojis.py
- Gun_Game
- strip_white_bg.py
- sweep_sniper.py
- layout_check.py
- scan_arms.py
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- Lalezar font
- shop.tscn scene
- weapon_card.tscn
- Arena
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- DemonState
- Arena
- Hub
- Arena
- gun_game_server
- Player

## God Nodes (most connected - your core abstractions)
1. `col()` - 121 edges
2. `httpError()` - 65 edges
3. `enableCORS()` - 58 edges
4. `jsonResponse()` - 53 edges
5. `Hub` - 51 edges
6. `NewHub()` - 50 edges
7. `getPlayerByUsername()` - 47 edges
8. `PlayerModel` - 43 edges
9. `Player` - 41 edges
10. `RoundState` - 34 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `cityLeaderboardEntry()` --calls--> `clanLeaderInfo()`  [INFERRED]
  gun_game_server/handlers_leaderboard.go → gun_game_server/handlers_clan.go
- `clanWorldRank()` --calls--> `cityStanding()`  [INFERRED]
  gun_game_server/handlers_clan.go → gun_game_server/handlers_leaderboard.go
- `checkAndUnlockAchievements()` --calls--> `col()`  [INFERRED]
  gun_game_server/achievements.go → gun_game_server/db.go
- `loadAchievementDefs()` --calls--> `col()`  [INFERRED]
  gun_game_server/achievements.go → gun_game_server/db.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (73 total, 19 thin omitted)

### Community 0 - "col"
Cohesion: 0.07
Nodes (142): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, guardStatus(), TestProtectedAccountFlow(), TestMaskEmailAndAuthPageEscaping(), TestSessionMatchesOnlyTheRightToken(), authProbe (+134 more)

### Community 1 - "context.Context"
Cohesion: 0.05
Nodes (78): AchievementDef, context.Context, go.mongodb.org/mongo-driver/bson.M, net/http/httptest.ResponseRecorder, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), MatchParticipant (+70 more)

### Community 2 - "applyLoadout"
Cohesion: 0.06
Nodes (60): TestBombStockIsThreePerMatch(), TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor() (+52 more)

### Community 3 - "matchmaking.go"
Cohesion: 0.07
Nodes (59): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), keysOf(), loadBotsNear(), makeBot(), makeBotName() (+51 more)

### Community 4 - "Hub"
Cohesion: 0.07
Nodes (30): bufio.Scanner, github.com/gorilla/websocket.Conn, net/http.HandlerFunc, TestApplyDotEnvKeepsExistingEnv(), TestServerKeyOnlyIsClosedWithoutKey(), Client, SetPlayerOnline(), applyDotEnv() (+22 more)

### Community 5 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 6 - "LoadArena"
Cohesion: 0.13
Nodes (28): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), parseArena(), addPlayer(), containsStr(), Hub (+20 more)

### Community 7 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 8 - "testing.T"
Cohesion: 0.13
Nodes (25): testing.T, nextAchievement(), makeIDToken(), TestAchievementCatalogIsSane(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody(), TestAuthGuardPassesThroughWithoutDatabase(), TestBearerToken(), TestGoogleClaimsValidation() (+17 more)

### Community 9 - "Player"
Cohesion: 0.21
Nodes (11): laserSegment(), arenaOf(), Hub, turnStep(), BotRuntime, botSkillProfile, CharStats, statsOf() (+3 more)

### Community 10 - "models.go"
Cohesion: 0.09
Nodes (24): AchievementDef, ChatReadBody, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanMemberActionBody, ClanRespondBody, ClanUpdateBody (+16 more)

### Community 11 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 12 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 13 - "RoundState"
Cohesion: 0.23
Nodes (6): BotRuntime, Hub, Player, DemonState, RoundState, LiveObjective

### Community 14 - "Hub"
Cohesion: 0.17
Nodes (9): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserTickDamage(), refreshAbilityTimers(), segmentHitsCircle() (+1 more)

### Community 15 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 16 - "Hub"
Cohesion: 0.16
Nodes (11): DailyMissionDoc, minInt(), LiveObjective, buildObjectives(), Hub, liveDelta(), buildSeasonChallengeView(), TestSeasonChallengeView() (+3 more)

### Community 17 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 18 - "demon_test.go"
Cohesion: 0.17
Nodes (19): absF(), Arena, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates(), TestDemonDiesWithEqualDamageIsADraw() (+11 more)

### Community 19 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 20 - "time.Time"
Cohesion: 0.16
Nodes (16): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, ChatReadModel, ClanJoinRequestModel, ClanMember, DailyMissionDoc, FriendRequestModel, GoogleAuthPending (+8 more)

### Community 21 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 22 - "handlers_chat.go"
Cohesion: 0.24
Nodes (16): ChatMessageModel, allowChatSend(), chatLastRead(), chatPeople(), cityRoomID(), containsString(), countChatUnread(), fillLastMessage() (+8 more)

### Community 23 - "missions_test.go"
Cohesion: 0.15
Nodes (16): DailyBonusTier, buildDailyBonusView(), dailyBonusTierByNeed(), missionSeed(), pickDailyMissions(), TestBuildDailyBonusViewDoesNotMutateTable(), TestBuildDailyBonusViewStates(), TestCurrentSeasonPassNormalisesNewFields() (+8 more)

### Community 25 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 26 - "PlayerModel"
Cohesion: 0.16
Nodes (11): buildSeasonCupsResponse(), seasonXPOf(), PlayerModel, PlayerSeasonCups, PlayerSeasonPass, PlayerStats, PublicProfile, RecentMatch (+3 more)

### Community 27 - "NewHub"
Cohesion: 0.33
Nodes (13): NewHub(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestOnlyTheWinningTeamWinsANormalRound() (+5 more)

### Community 28 - "missions.go"
Cohesion: 0.29
Nodes (12): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, MissionDifficulty, MissionMetric, dailyMissionIndexes(), SeasonPassLadder(), SeasonPassPremiumLadder(), seasonPassPremiumReward() (+4 more)

### Community 29 - "Arena"
Cohesion: 0.31
Nodes (4): Arena, clampF(), arenaFile, Room

### Community 30 - "distance"
Cohesion: 0.18
Nodes (8): Arena, BotRuntime, Hub, patrolPoint(), Arena, newDemon(), TestNoSpawnSitsOnTheDemon(), distance()

### Community 31 - "angleDiff"
Cohesion: 0.44
Nodes (10): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), angleDiff(), clampRotation() (+2 more)

### Community 32 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 33 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 34 - "googleClaims"
Cohesion: 0.43
Nodes (7): TestClaimsFromTokenInfoStrings(), googleClaims, asString(), claimsFromMap(), exchangeGoogleCode(), parseIDTokenPayload(), verifyGoogleIDToken()

### Community 35 - "seedClaimPlayer"
Cohesion: 0.61
Nodes (7): coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull()

### Community 36 - "buildMissionsResponse"
Cohesion: 0.33
Nodes (7): buildMissionsResponse(), DailyMissionDoc, dailyBonusMaxNeed(), missionDayEnd(), missionSecondsLeft(), TestDailyBonusTiersAreAscending(), TestMissionSecondsLeftRange()

### Community 37 - "applyMatchToSeasonStats"
Cohesion: 0.43
Nodes (7): MatchParticipant, persistMatchMissions(), applyMatchToMissions(), applyMatchToSeasonStats(), missionDeltas(), TestMissionDeltas(), MatchParticipant

### Community 38 - "seasonPassXPRequired"
Cohesion: 0.43
Nodes (7): seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestSeasonPassMaxLevelBarStaysFull(), TestSeasonPassProgress(), TestSeasonPassTotalMatchesProgress()

### Community 39 - "time.Duration"
Cohesion: 0.29
Nodes (5): time.Duration, Player, spawnShieldFor(), ModeOfMatch(), RoundRules

### Community 40 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 41 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 42 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 43 - "loadOrCreateDailyMissions"
Cohesion: 0.50
Nodes (5): DailyMissionDoc, loadOrCreateDailyMissions(), missionDayKey(), repairMissionStates(), TestMissionDayBoundary()

### Community 44 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 45 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 46 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 47 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **48 isolated node(s):** `googleStartBody`, `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonPassBuyBody` (+43 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **19 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `context.Context`, `applyLoadout`, `matchmaking.go`, `Hub`, `seedClaimPlayer`, `applyMatchToSeasonStats`, `loadOrCreateDailyMissions`, `weekly_rewards.go`, `handlers_chat.go`?**
  _High betweenness centrality (0.107) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `applyLoadout`, `Hub`, `LoadArena`, `models.go`, `bot_sense_test.go`, `Hub`, `mustArena`, `time.Time`, `abilities_test.go`, `Arena`, `distance`?**
  _High betweenness centrality (0.052) - this node is a cross-community bridge._
- **Why does `RoundState` connect `RoundState` to `Hub`, `LoadArena`, `time.Duration`, `Hub`, `demon_test.go`, `time.Time`, `Hub`, `NewHub`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Are the 111 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 111 INFERRED edges - model-reasoned connections that need verification._
- **Are the 56 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 56 INFERRED edges - model-reasoned connections that need verification._
- **What connects `googleStartBody`, `DailyBonusClaimBody`, `MissionClaimBody` to the rest of the system?**
  _48 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.06568232662192394 - nodes in this community are weakly interconnected._