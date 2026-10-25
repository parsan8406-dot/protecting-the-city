# Graph Report - gun-game  (2026-09-16)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1104 nodes · 3368 edges · 64 communities (48 shown, 16 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 870 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- context.Context
- handlers_auth.go
- applyLoadout
- Hub
- missions.go
- build_arena.py
- matchmaking.go
- testing.T
- patch_scenes.py
- models.go
- distance
- build_rig.py
- PlayerModel
- Player
- Row Sheet UI Asset Preview Page
- RoundState
- mustArena
- time.Time
- LoadArena
- weekly_rewards.go
- demon_test.go
- .FindPath
- abilities_test.go
- Arena
- NewHub
- revenge_test.go
- profileFor
- statsOf
- deform_check.py
- time.Duration
- .teamRoomsFor
- pathArena
- ClanModel
- dependencies
- arm_angles.py
- solve
- prepare_chat_emojis.py
- Gun_Game
- strip_white_bg.py
- sweep_sniper.py
- PlayerStats
- layout_check.py
- scan_arms.py
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- Lalezar font
- shop.tscn scene
- weapon_card.tscn
- BotRuntime
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Arena
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 117 edges
2. `httpError()` - 65 edges
3. `enableCORS()` - 58 edges
4. `jsonResponse()` - 53 edges
5. `Hub` - 51 edges
6. `NewHub()` - 49 edges
7. `getPlayerByUsername()` - 47 edges
8. `PlayerModel` - 45 edges
9. `Player` - 43 edges
10. `RoundState` - 33 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `persistMatchMissions()` --calls--> `applyMatchToMissions()`  [INFERRED]
  gun_game_server/match_objectives.go → gun_game_server/missions.go
- `persistMatchMissions()` --calls--> `applyMatchToSeasonStats()`  [INFERRED]
  gun_game_server/match_objectives.go → gun_game_server/missions.go
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

## Communities (64 total, 16 thin omitted)

### Community 0 - "col"
Cohesion: 0.09
Nodes (105): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, DailyBonusClaimBody, col(), newID(), getGameModesHandler(), selectGameModeHandler() (+97 more)

### Community 1 - "context.Context"
Cohesion: 0.05
Nodes (82): AchievementDef, context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, net/http/httptest.ResponseRecorder, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements(), MatchParticipant (+74 more)

### Community 2 - "handlers_auth.go"
Cohesion: 0.07
Nodes (63): bufio.Scanner, net/http.HandlerFunc, guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestAchievementCatalogIsSane() (+55 more)

### Community 3 - "applyLoadout"
Cohesion: 0.06
Nodes (61): TestBombStockIsThreePerMatch(), TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor() (+53 more)

### Community 4 - "Hub"
Cohesion: 0.07
Nodes (35): github.com/gorilla/websocket.Conn, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, Client, SetPlayerOnline(), equippedFor() (+27 more)

### Community 5 - "missions.go"
Cohesion: 0.06
Nodes (54): DailyMissionDoc, DailyBonusTier, DailyMissionDef, minInt(), LiveObjective, buildObjectives(), Hub, MatchParticipant (+46 more)

### Community 6 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 7 - "matchmaking.go"
Cohesion: 0.12
Nodes (37): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), myRankCard() (+29 more)

### Community 8 - "testing.T"
Cohesion: 0.14
Nodes (26): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotIgnoresFriendlyGunfire() (+18 more)

### Community 9 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 10 - "models.go"
Cohesion: 0.08
Nodes (26): AchievementDef, BuyRequest, ChatReadBody, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanMemberActionBody, ClanRespondBody (+18 more)

### Community 11 - "distance"
Cohesion: 0.15
Nodes (10): arenaOf(), Arena, BotRuntime, Hub, patrolPoint(), Hub, BotRuntime, botSkillProfile (+2 more)

### Community 12 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 13 - "PlayerModel"
Cohesion: 0.17
Nodes (21): go.mongodb.org/mongo-driver/bson.M, cityPointsRow, buildSeasonCupsResponse(), cityPointsStages(), cityStanding(), clansByID(), fillCityLeaderboard(), fillPlayerLeaderboard() (+13 more)

### Community 14 - "Player"
Cohesion: 0.17
Nodes (12): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), refreshAbilityTimers() (+4 more)

### Community 15 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 16 - "RoundState"
Cohesion: 0.14
Nodes (6): DemonState, Hub, newDemon(), DemonState, Hub, RoundState

### Community 17 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 18 - "time.Time"
Cohesion: 0.17
Nodes (18): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, TestPersonalizeBroadcasts(), ChatReadModel, ClanJoinRequestModel, DailyMissionDoc, FriendRequestModel, GoogleAuthPending (+10 more)

### Community 19 - "LoadArena"
Cohesion: 0.20
Nodes (18): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), addPlayer(), containsStr(), Hub, keysOfPlayers(), TestBotTargetsOnlyEnemiesInItsOwnMatch() (+10 more)

### Community 20 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 21 - "demon_test.go"
Cohesion: 0.21
Nodes (16): Arena, absF(), Hub, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates() (+8 more)

### Community 22 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 23 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 24 - "Arena"
Cohesion: 0.25
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 26 - "NewHub"
Cohesion: 0.33
Nodes (13): NewHub(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestOnlyTheWinningTeamWinsANormalRound() (+5 more)

### Community 27 - "revenge_test.go"
Cohesion: 0.27
Nodes (11): TestDemonHuntRules(), rulesForMode(), Hub, newRevengeRound(), TestJoinRoundIsIdempotent(), TestLateJoinerStillRespawns(), TestRevengeDeathIsTemporary(), TestRevengeEqualScoreIsADraw() (+3 more)

### Community 28 - "profileFor"
Cohesion: 0.42
Nodes (10): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+2 more)

### Community 29 - "statsOf"
Cohesion: 0.33
Nodes (12): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), turnStep(), angleDiff() (+4 more)

### Community 31 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 32 - "time.Duration"
Cohesion: 0.29
Nodes (5): time.Duration, spawnShieldFor(), ModeOfMatch(), RoundRules, Player

### Community 33 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 34 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 35 - "ClanModel"
Cohesion: 0.40
Nodes (5): ClanMember, ClanModel, clanLeaderInfo(), clanWorldRank(), cityLeaderboardEntry()

### Community 36 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 37 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 38 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 39 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 40 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 41 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 42 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **48 isolated node(s):** `SeasonCupClaimBody`, `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonPassBuyBody` (+43 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `context.Context`, `handlers_auth.go`, `applyLoadout`, `Hub`, `matchmaking.go`, `PlayerModel`, `weekly_rewards.go`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `applyLoadout`, `Hub`, `testing.T`, `models.go`, `distance`, `RoundState`, `mustArena`, `time.Time`, `LoadArena`, `abilities_test.go`, `Arena`, `profileFor`, `statsOf`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `applyLoadout`, `distance`, `Player`, `RoundState`, `time.Time`, `NewHub`, `statsOf`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Are the 107 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 107 INFERRED edges - model-reasoned connections that need verification._
- **Are the 56 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 56 INFERRED edges - model-reasoned connections that need verification._
- **What connects `SeasonCupClaimBody`, `DailyBonusClaimBody`, `MissionClaimBody` to the rest of the system?**
  _48 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.09362934362934362 - nodes in this community are weakly interconnected._