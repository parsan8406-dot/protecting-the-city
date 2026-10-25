# Graph Report - gun-game  (2026-09-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 970 nodes · 2867 edges · 58 communities (44 shown, 14 thin omitted)
- Extraction: 75% EXTRACTED · 25% INFERRED · 0% AMBIGUOUS · INFERRED: 730 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- missions.go
- Hub
- context.Context
- balance.go
- build_arena.py
- matchmaking.go
- Player
- models.go
- testing.T
- patch_scenes.py
- LoadArena
- RoundState
- Player
- build_rig.py
- ClanModel
- Row Sheet UI Asset Preview Page
- weekly_rewards.go
- mustArena
- .FindPath
- abilities_test.go
- PlayerModel
- applyLoadout
- NewHub
- Arena
- profileFor
- deform_check.py
- .teamRoomsFor
- pathArena
- dependencies
- arm_angles.py
- solve
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
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Arena
- Arena
- gun_game_server
- time.Time

## God Nodes (most connected - your core abstractions)
1. `col()` - 102 edges
2. `httpError()` - 55 edges
3. `enableCORS()` - 51 edges
4. `Hub` - 51 edges
5. `jsonResponse()` - 46 edges
6. `getPlayerByUsername()` - 43 edges
7. `PlayerModel` - 43 edges
8. `NewHub()` - 39 edges
9. `mustArena()` - 25 edges
10. `Player` - 23 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `spawnShieldFor()` --calls--> `ModeOfMatch()`  [INFERRED]
  gun_game_server/match_round.go → gun_game_server/mm_backfill.go
- `getGameModesHandler()` --calls--> `rankFromTrophies()`  [INFERRED]
  gun_game_server/game_modes.go → gun_game_server/matchmaking.go
- `broadcastChatMessage()` --calls--> `getClanByID()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/handlers_clan.go
- `fillCityLeaderboard()` --calls--> `getClanByID()`  [INFERRED]
  gun_game_server/handlers_leaderboard.go → gun_game_server/handlers_clan.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (58 total, 14 thin omitted)

### Community 0 - "col"
Cohesion: 0.08
Nodes (112): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, ChatMessageModel, DailyBonusClaimBody, col(), newID(), getGameModesHandler() (+104 more)

### Community 1 - "missions.go"
Cohesion: 0.06
Nodes (58): DailyMissionDoc, DailyBonusTier, DailyMissionDef, DailyMissionDoc, buildMissionsResponse(), minInt(), LiveObjective, buildObjectives() (+50 more)

### Community 2 - "Hub"
Cohesion: 0.07
Nodes (38): BotRuntime, github.com/gorilla/websocket.Conn, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), BotSeat, Client, SetPlayerOnline() (+30 more)

### Community 3 - "context.Context"
Cohesion: 0.07
Nodes (55): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, net/http.HandlerFunc, net/http/httptest.ResponseRecorder, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID() (+47 more)

### Community 4 - "balance.go"
Cohesion: 0.07
Nodes (50): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+42 more)

### Community 5 - "build_arena.py"
Cohesion: 0.08
Nodes (43): ndarray, Random, border_rects(), build_map(), build_obstacles(), build_rooms(), circle_free(), _connected() (+35 more)

### Community 6 - "matchmaking.go"
Cohesion: 0.11
Nodes (40): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), gameModeByID() (+32 more)

### Community 7 - "Player"
Cohesion: 0.12
Nodes (24): CharStats, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), arenaOf() (+16 more)

### Community 8 - "models.go"
Cohesion: 0.09
Nodes (23): BuyRequest, ChatReadBody, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanMemberActionBody, ClanRespondBody, ClanUpdateBody (+15 more)

### Community 9 - "testing.T"
Cohesion: 0.14
Nodes (26): testing.T, Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotIgnoresFriendlyGunfire() (+18 more)

### Community 10 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 11 - "LoadArena"
Cohesion: 0.14
Nodes (27): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), addPlayer(), containsStr(), Hub, keysOfPlayers() (+19 more)

### Community 12 - "RoundState"
Cohesion: 0.21
Nodes (7): time.Duration, Hub, rulesForMode(), spawnShieldFor(), TestRevengeRules(), RoundRules, RoundState

### Community 13 - "Player"
Cohesion: 0.19
Nodes (11): abilityKey(), bombStockKey(), canBeHurt(), Hub, Player, isGuarded(), laserSegment(), laserTickDamage() (+3 more)

### Community 14 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 15 - "ClanModel"
Cohesion: 0.17
Nodes (19): go.mongodb.org/mongo-driver/bson.M, cityPointsRow, ClanMember, ClanModel, clanLeaderInfo(), clanWorldRank(), cityLeaderboardEntry(), cityPointsStages() (+11 more)

### Community 16 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 17 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 18 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 19 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 20 - "abilities_test.go"
Cohesion: 0.32
Nodes (15): Arena, abilityClient(), abilityPlayer(), corridorFree(), Hub, Player, openCorridor(), runLaser() (+7 more)

### Community 21 - "PlayerModel"
Cohesion: 0.21
Nodes (9): buildSeasonCupsResponse(), seasonXPOf(), PlayerAuth, PlayerModel, PlayerSeasonCups, PlayerStats, PublicProfile, currentSeasonCups() (+1 more)

### Community 22 - "applyLoadout"
Cohesion: 0.31
Nodes (11): TestBombStockIsThreePerMatch(), addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput() (+3 more)

### Community 23 - "NewHub"
Cohesion: 0.32
Nodes (12): TestPracticeArenaRefillsBombsOnEntry(), NewHub(), Hub, newRound(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestRoundDurationIsSane() (+4 more)

### Community 24 - "Arena"
Cohesion: 0.31
Nodes (4): clampF(), Arena, parseArena(), arenaFile

### Community 25 - "profileFor"
Cohesion: 0.42
Nodes (10): TestBotFacesTheDirectionItWalks(), profileFor(), blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer() (+2 more)

### Community 26 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 27 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 28 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 29 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 30 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 31 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 32 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 33 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 34 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 35 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

### Community 57 - "time.Time"
Cohesion: 0.21
Nodes (12): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, ChatReadModel, ClanJoinRequestModel, FriendRequestModel, MatchRecord, MessageModel (+4 more)

## Knowledge Gaps
- **47 isolated node(s):** `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonCupClaimBody`, `SeasonPassBuyBody` (+42 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `missions.go`, `Hub`, `context.Context`, `balance.go`, `matchmaking.go`, `ClanModel`, `weekly_rewards.go`?**
  _High betweenness centrality (0.092) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `balance.go`, `Player`, `applyLoadout`, `NewHub`, `time.Time`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Why does `Player` connect `Player` to `balance.go`, `models.go`, `testing.T`, `LoadArena`, `RoundState`, `mustArena`, `abilities_test.go`, `applyLoadout`, `profileFor`, `time.Time`?**
  _High betweenness centrality (0.046) - this node is a cross-community bridge._
- **Are the 91 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `loadBotsNear()`) actually correct?**
  _`col()` has 91 INFERRED edges - model-reasoned connections that need verification._
- **Are the 46 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 46 INFERRED edges - model-reasoned connections that need verification._
- **What connects `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody` to the rest of the system?**
  _47 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.08431847315197265 - nodes in this community are weakly interconnected._