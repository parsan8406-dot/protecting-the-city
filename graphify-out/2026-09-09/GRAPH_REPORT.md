# Graph Report - gun-game  (2026-09-08)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 821 nodes · 2379 edges · 51 communities (36 shown, 15 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 615 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- Hub
- models.go
- missions.go
- applyLoadout
- mm_backfill.go
- build_arena.py
- patch_scenes.py
- withDB
- testing.T
- RoundState
- db.go
- build_rig.py
- NewHub
- Row Sheet UI Asset Preview Page
- mustArena
- LoadArena
- .FindPath
- Arena
- bot_sense_test.go
- profileFor
- deform_check.py
- .teamRoomsFor
- defaultGameModes
- dependencies
- arm_angles.py
- solve
- Gun_Game
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
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Arena
- Arena
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 92 edges
2. `httpError()` - 51 edges
3. `Hub` - 51 edges
4. `enableCORS()` - 47 edges
5. `jsonResponse()` - 42 edges
6. `getPlayerByUsername()` - 39 edges
7. `PlayerModel` - 39 edges
8. `NewHub()` - 32 edges
9. `Player` - 28 edges
10. `Arena` - 22 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `broadcastChatMessage()` --calls--> `NotifyEveryone()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/hub.go
- `broadcastChatMessage()` --calls--> `NotifyUsers()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/hub.go
- `getLeaderboardHandler()` --calls--> `enableCORS()`  [INFERRED]
  gun_game_server/handlers_leaderboard.go → gun_game_server/handlers.go
- `getPlayerHandler()` --calls--> `GenerateUniquePlayerID()`  [INFERRED]
  gun_game_server/handlers.go → gun_game_server/db.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (51 total, 15 thin omitted)

### Community 0 - "col"
Cohesion: 0.10
Nodes (101): context.Context, go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, ChatMessageModel, ClanModel, col(), newID() (+93 more)

### Community 1 - "Hub"
Cohesion: 0.06
Nodes (40): BotRuntime, github.com/gorilla/websocket.Conn, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly() (+32 more)

### Community 2 - "models.go"
Cohesion: 0.06
Nodes (55): go.mongodb.org/mongo-driver/bson.M, go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody (+47 more)

### Community 3 - "missions.go"
Cohesion: 0.07
Nodes (52): DailyBonusClaimBody, DailyBonusTier, DailyMissionDef, DailyMissionDoc, buildMissionsResponse(), buildSeasonPassResponse(), levelFromExperience(), minInt() (+44 more)

### Community 4 - "applyLoadout"
Cohesion: 0.08
Nodes (47): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+39 more)

### Community 5 - "mm_backfill.go"
Cohesion: 0.09
Nodes (38): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), keysOf(), loadBotsExcluding(), makeBot(), makeBotName() (+30 more)

### Community 6 - "build_arena.py"
Cohesion: 0.10
Nodes (34): ndarray, Random, border_rects(), build_map(), build_pillars(), build_rooms(), circle_free(), main() (+26 more)

### Community 7 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 8 - "withDB"
Cohesion: 0.17
Nodes (25): net/http/httptest.ResponseRecorder, ApplyMatchResult(), reload(), seedRewardPlayer(), TestLosingDeductsTrophiesAndNothingElse(), TestTrophiesNeverGoNegativeOnALoss(), TestWinningPaysTrophiesCoinsAndXP(), withDB() (+17 more)

### Community 9 - "testing.T"
Cohesion: 0.15
Nodes (24): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget() (+16 more)

### Community 10 - "RoundState"
Cohesion: 0.18
Nodes (8): time.Duration, Hub, rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules, RoundState

### Community 11 - "db.go"
Cohesion: 0.13
Nodes (21): go.mongodb.org/mongo-driver/mongo.IndexModel, net/http.HandlerFunc, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+13 more)

### Community 12 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 13 - "NewHub"
Cohesion: 0.21
Nodes (19): NewHub(), Hub, newRound(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestRoundDurationIsSane(), TestRoundEndsOnlyOnce() (+11 more)

### Community 14 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 15 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 16 - "LoadArena"
Cohesion: 0.20
Nodes (18): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), addPlayer(), containsStr(), Hub, keysOfPlayers(), TestBotTargetsOnlyEnemiesInItsOwnMatch() (+10 more)

### Community 17 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 18 - "Arena"
Cohesion: 0.25
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 19 - "bot_sense_test.go"
Cohesion: 0.25
Nodes (13): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotIgnoresFriendlyGunfire(), TestBotNeverSensesATeammateAsTarget() (+5 more)

### Community 20 - "profileFor"
Cohesion: 0.42
Nodes (10): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+2 more)

### Community 21 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 22 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 23 - "defaultGameModes"
Cohesion: 0.47
Nodes (5): defaultGameModes(), TestDefaultGameModesAreWellFormed(), TestGameModeEconomyIsSane(), TestSmallerTeamsPayMore(), TestRevengeIsOneVersusOne()

### Community 24 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 25 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 26 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 27 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 28 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **42 isolated node(s):** `catalogPrice`, `pfNode`, `arenaFile`, `ChatReadBody`, `ChatSendBody` (+37 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `Hub`, `models.go`, `missions.go`, `applyLoadout`, `mm_backfill.go`, `withDB`, `db.go`?**
  _High betweenness centrality (0.094) - this node is a cross-community bridge._
- **Why does `Player` connect `Hub` to `models.go`, `applyLoadout`, `RoundState`, `mustArena`, `LoadArena`, `Arena`, `bot_sense_test.go`, `profileFor`?**
  _High betweenness centrality (0.063) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `models.go`, `applyLoadout`, `RoundState`, `NewHub`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Are the 81 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `loadBotsExcluding()`) actually correct?**
  _`col()` has 81 INFERRED edges - model-reasoned connections that need verification._
- **Are the 42 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 42 INFERRED edges - model-reasoned connections that need verification._
- **What connects `catalogPrice`, `pfNode`, `arenaFile` to the rest of the system?**
  _42 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.09726548978885427 - nodes in this community are weakly interconnected._