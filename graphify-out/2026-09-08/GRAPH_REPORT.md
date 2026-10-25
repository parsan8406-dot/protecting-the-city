# Graph Report - gun-game  (2026-09-08)

## Corpus Check
- 75 files · ~92,572 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 807 nodes · 2341 edges · 52 communities (39 shown, 13 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 600 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- Hub
- NewDefaultPlayer
- models.go
- LoadArena
- patch_scenes.py
- missions_test.go
- build_arena.py
- mm_backfill.go
- Arena
- context.Context
- build_rig.py
- applyLoadout
- Row Sheet UI Asset Preview Page
- Player
- mustArena
- .FindPath
- RoundState
- testing.T
- handlers_missions.go
- currentSeasonPass
- missions.go
- bot_sense_test.go
- NewHub
- deform_check.py
- newBotHub
- distance
- pathArena
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
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 91 edges
2. `Hub` - 51 edges
3. `httpError()` - 50 edges
4. `enableCORS()` - 46 edges
5. `jsonResponse()` - 41 edges
6. `PlayerModel` - 39 edges
7. `getPlayerByUsername()` - 38 edges
8. `NewHub()` - 32 edges
9. `Player` - 28 edges
10. `Arena` - 19 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `TestCheatingClientCannotInstantTurnToFire()` --calls--> `applyLoadout()`  [INFERRED]
  gun_game_server/anticheat_test.go → gun_game_server/hub.go
- `TestHitActionIsRateLimited()` --calls--> `NewHub()`  [INFERRED]
  gun_game_server/anticheat_test.go → gun_game_server/hub.go
- `mustArena()` --calls--> `LoadArena()`  [INFERRED]
  gun_game_server/arena_test.go → gun_game_server/arena.go
- `newBotHub()` --calls--> `LoadArena()`  [INFERRED]
  gun_game_server/botai_test.go → gun_game_server/arena.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (52 total, 13 thin omitted)

### Community 0 - "col"
Cohesion: 0.10
Nodes (96): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, ChatMessageModel, ClanModel, col(), newID(), getGameModesHandler() (+88 more)

### Community 1 - "Hub"
Cohesion: 0.10
Nodes (18): BotRuntime, github.com/gorilla/websocket.Conn, Client, SetPlayerOnline(), equippedFor(), Hub, Hub, NotifyEveryone() (+10 more)

### Community 2 - "NewDefaultPlayer"
Cohesion: 0.67
Nodes (3): NewDefaultPlayer(), NewDefaultRank(), PlayerRank

### Community 3 - "models.go"
Cohesion: 0.09
Nodes (34): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, BuyRequest, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody (+26 more)

### Community 4 - "LoadArena"
Cohesion: 0.19
Nodes (15): net/http.HandlerFunc, TestHitActionIsRateLimited(), LoadArena(), corsMiddleware(), main(), addPlayer(), containsStr(), Hub (+7 more)

### Community 5 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 6 - "missions_test.go"
Cohesion: 0.20
Nodes (16): buildSeasonPassResponse(), missionSeed(), pickDailyMissions(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestMissionDeltas() (+8 more)

### Community 7 - "build_arena.py"
Cohesion: 0.10
Nodes (34): ndarray, Random, border_rects(), build_map(), build_pillars(), build_rooms(), circle_free(), main() (+26 more)

### Community 8 - "mm_backfill.go"
Cohesion: 0.10
Nodes (36): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), keysOf(), loadBotsExcluding(), makeBot(), makeBotName() (+28 more)

### Community 9 - "Arena"
Cohesion: 0.16
Nodes (8): clampF(), Arena, MapNameForMode(), parseArena(), arenaFile, Room, Arena, hashString()

### Community 10 - "context.Context"
Cohesion: 0.06
Nodes (68): context.Context, go.mongodb.org/mongo-driver/bson.M, net/http/httptest.ResponseRecorder, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase() (+60 more)

### Community 11 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 12 - "applyLoadout"
Cohesion: 0.07
Nodes (50): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+42 more)

### Community 13 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 14 - "Player"
Cohesion: 0.12
Nodes (22): isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), arenaOf(), Arena (+14 more)

### Community 15 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 16 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 17 - "RoundState"
Cohesion: 0.20
Nodes (8): time.Duration, Hub, rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules, RoundState

### Community 18 - "testing.T"
Cohesion: 0.21
Nodes (15): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget() (+7 more)

### Community 19 - "handlers_missions.go"
Cohesion: 0.22
Nodes (10): buildMissionsResponse(), levelFromExperience(), minInt(), MissionClaimBody, missionDayEnd(), missionSecondsLeft(), TestLevelFromExperience(), TestMissionDayBoundary() (+2 more)

### Community 21 - "missions.go"
Cohesion: 0.20
Nodes (16): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, MatchParticipant, MatchResultBody, MissionDifficulty, MissionMetric, applyMatchToMissions(), dailyMissionIndexes() (+8 more)

### Community 22 - "bot_sense_test.go"
Cohesion: 0.24
Nodes (15): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire(), TestBotNeverSensesATeammateAsTarget() (+7 more)

### Community 23 - "NewHub"
Cohesion: 0.36
Nodes (11): NewHub(), Hub, newRound(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestRoundDurationIsSane(), TestRoundEndsOnlyOnce() (+3 more)

### Community 24 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 25 - "newBotHub"
Cohesion: 0.47
Nodes (8): blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer(), TestBotRespawnsSomewhereValid(), TestBotsLeaveWhenNoHumansRemain()

### Community 26 - "distance"
Cohesion: 0.21
Nodes (16): ArenaForMode(), TestBotDoesNotSeeThroughWalls(), distance(), Hub, newRevengeRound(), TestAttackingEndsYourOwnShield(), TestJoinRoundIsIdempotent(), TestLateJoinerStillRespawns() (+8 more)

### Community 27 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 28 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 29 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 30 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 31 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 32 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **41 isolated node(s):** `net8.0`, `net9.0`, `Godot.NET.Sdk/4.7.1`, `arenaFile`, `gun_game_server` (+36 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `Hub`, `mm_backfill.go`, `context.Context`, `applyLoadout`, `missions.go`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `Hub`, `models.go`, `LoadArena`, `applyLoadout`, `mustArena`, `RoundState`, `bot_sense_test.go`, `newBotHub`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `models.go`, `applyLoadout`, `Player`, `RoundState`, `NewHub`, `distance`?**
  _High betweenness centrality (0.065) - this node is a cross-community bridge._
- **Are the 80 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `loadBotsExcluding()`) actually correct?**
  _`col()` has 80 INFERRED edges - model-reasoned connections that need verification._
- **What connects `net8.0`, `net9.0`, `Godot.NET.Sdk/4.7.1` to the rest of the system?**
  _41 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.10095127159774801 - nodes in this community are weakly interconnected._
- **Should `Hub` be split into smaller, more focused modules?**
  _Cohesion score 0.10434782608695652 - nodes in this community are weakly interconnected._