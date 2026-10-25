# Graph Report - gun-game  (2026-09-10)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 839 nodes · 2437 edges · 52 communities (37 shown, 15 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 640 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- context.Context
- missions.go
- applyLoadout
- Hub
- models.go
- Player
- build_arena.py
- mm_backfill.go
- patch_scenes.py
- testing.T
- RoundState
- build_rig.py
- Row Sheet UI Asset Preview Page
- mustArena
- LoadArena
- .FindPath
- bot_sense_test.go
- Arena
- NewHub
- revenge_test.go
- newBotHub
- deform_check.py
- .teamRoomsFor
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
- Arena
- Arena
- Arena
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 95 edges
2. `httpError()` - 53 edges
3. `Hub` - 51 edges
4. `enableCORS()` - 49 edges
5. `jsonResponse()` - 44 edges
6. `getPlayerByUsername()` - 41 edges
7. `PlayerModel` - 38 edges
8. `NewHub()` - 32 edges
9. `Player` - 28 edges
10. `Arena` - 21 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `SeedCharacterStats()` --calls--> `col()`  [INFERRED]
  gun_game_server/balance.go → gun_game_server/db.go
- `loadBotsExcluding()` --calls--> `col()`  [INFERRED]
  gun_game_server/bots.go → gun_game_server/db.go
- `seedBots()` --calls--> `col()`  [INFERRED]
  gun_game_server/bots.go → gun_game_server/db.go
- `ApplyMatchResult()` --calls--> `col()`  [INFERRED]
  gun_game_server/game_modes.go → gun_game_server/db.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (52 total, 15 thin omitted)

### Community 0 - "col"
Cohesion: 0.09
Nodes (105): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, ClanModel, DailyBonusClaimBody, col(), newID(), getGameModesHandler() (+97 more)

### Community 1 - "context.Context"
Cohesion: 0.06
Nodes (71): context.Context, go.mongodb.org/mongo-driver/bson.M, math/rand.Rand, net/http/httptest.ResponseRecorder, keysOf(), loadBotsExcluding(), makeBot(), makeBotName() (+63 more)

### Community 2 - "missions.go"
Cohesion: 0.07
Nodes (55): DailyMissionDoc, go.mongodb.org/mongo-driver/mongo.IndexModel, DailyBonusTier, DailyMissionDef, buildMissionsResponse(), buildSeasonPassResponse(), MissionDifficulty, MissionMetric (+47 more)

### Community 3 - "applyLoadout"
Cohesion: 0.08
Nodes (49): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+41 more)

### Community 4 - "Hub"
Cohesion: 0.09
Nodes (23): BotRuntime, github.com/gorilla/websocket.Conn, net/http.HandlerFunc, time.Duration, Client, SetPlayerOnline(), broadcastChatMessage(), equippedFor() (+15 more)

### Community 5 - "models.go"
Cohesion: 0.07
Nodes (43): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, BuyRequest, ChatMessageModel, ChatReadBody, ChatReadModel, ChatSendBody (+35 more)

### Community 6 - "Player"
Cohesion: 0.12
Nodes (24): Arena, CharStats, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly() (+16 more)

### Community 7 - "build_arena.py"
Cohesion: 0.10
Nodes (34): ndarray, Random, border_rects(), build_map(), build_pillars(), build_rooms(), circle_free(), main() (+26 more)

### Community 8 - "mm_backfill.go"
Cohesion: 0.14
Nodes (28): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, gameModeByID(), joinMatchmakingHandler(), matchmakingStatusHandler(), rankFromTrophies() (+20 more)

### Community 9 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 10 - "testing.T"
Cohesion: 0.14
Nodes (21): testing.T, shopRating(), TestNewGameplayHooksStayModerate(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget() (+13 more)

### Community 11 - "RoundState"
Cohesion: 0.20
Nodes (6): Hub, rulesForMode(), spawnShieldFor(), ModeOfMatch(), RoundRules, RoundState

### Community 12 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 13 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 14 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 15 - "LoadArena"
Cohesion: 0.20
Nodes (18): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), addPlayer(), containsStr(), Hub, keysOfPlayers(), TestBotTargetsOnlyEnemiesInItsOwnMatch() (+10 more)

### Community 16 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 17 - "bot_sense_test.go"
Cohesion: 0.24
Nodes (15): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+7 more)

### Community 18 - "Arena"
Cohesion: 0.25
Nodes (6): Arena, clampF(), MapNameForMode(), parseArena(), arenaFile, Room

### Community 19 - "NewHub"
Cohesion: 0.36
Nodes (11): NewHub(), Hub, newRound(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestRoundDurationIsSane(), TestRoundEndsOnlyOnce() (+3 more)

### Community 20 - "revenge_test.go"
Cohesion: 0.29
Nodes (10): Hub, newRevengeRound(), TestJoinRoundIsIdempotent(), TestLateJoinerStillRespawns(), TestRevengeDeathIsTemporary(), TestRevengeEqualScoreIsADraw(), TestRevengeIsOneVersusOne(), TestRevengeKillCredit() (+2 more)

### Community 21 - "newBotHub"
Cohesion: 0.47
Nodes (8): blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer(), TestBotRespawnsSomewhereValid(), TestBotsLeaveWhenNoHumansRemain()

### Community 22 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 23 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 24 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 25 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 26 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 27 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 28 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 29 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **44 isolated node(s):** `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonPassBuyBody`, `SeasonPassClaimBody` (+39 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `context.Context`, `missions.go`, `applyLoadout`, `Hub`, `models.go`, `mm_backfill.go`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `applyLoadout`, `models.go`, `Player`, `RoundState`, `NewHub`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `applyLoadout`, `Hub`, `models.go`, `RoundState`, `mustArena`, `LoadArena`, `bot_sense_test.go`, `newBotHub`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Are the 84 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `loadBotsExcluding()`) actually correct?**
  _`col()` has 84 INFERRED edges - model-reasoned connections that need verification._
- **Are the 44 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 44 INFERRED edges - model-reasoned connections that need verification._
- **What connects `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody` to the rest of the system?**
  _44 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.08770543615676359 - nodes in this community are weakly interconnected._