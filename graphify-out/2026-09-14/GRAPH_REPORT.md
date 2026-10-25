# Graph Report - gun-game  (2026-09-14)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 912 nodes · 2676 edges · 59 communities (42 shown, 17 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 687 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- Hub
- matchmaking.go
- balance.go
- missions.go
- build_arena.py
- context.Context
- patch_scenes.py
- withDB
- testing.T
- RoundState
- models.go
- build_rig.py
- Arena
- NewHub
- Row Sheet UI Asset Preview Page
- LoadArena
- weekly_rewards.go
- .FindPath
- bot_sense_test.go
- time.Time
- applyLoadout
- newBotHub
- deform_check.py
- pathArena
- bots_test.go
- dependencies
- arm_angles.py
- solve
- ClanModel
- prepare_chat_emojis.py
- Gun_Game
- main
- strip_white_bg.py
- sweep_sniper.py
- PlayerStats
- layout_check.py
- scan_arms.py
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- MessageReward
- PublicProfile
- ShopItem
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- Lalezar font
- shop.tscn scene
- weapon_card.tscn
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Hub
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 102 edges
2. `httpError()` - 55 edges
3. `enableCORS()` - 51 edges
4. `Hub` - 51 edges
5. `jsonResponse()` - 46 edges
6. `PlayerModel` - 44 edges
7. `getPlayerByUsername()` - 41 edges
8. `NewHub()` - 32 edges
9. `Player` - 28 edges
10. `getPlayerByID()` - 20 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `buildSeasonCupsResponse()` --calls--> `seasonCupDefs()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/season_cups.go
- `TestClaimSeasonCupRejectsBelowThreshold()` --calls--> `currentSeasonCups()`  [INFERRED]
  gun_game_server/season_cups_test.go → gun_game_server/season_cups.go
- `TestSeasonChallengeView()` --calls--> `buildSeasonChallengeView()`  [INFERRED]
  gun_game_server/missions_test.go → gun_game_server/missions.go
- `claimSeasonCupHandler()` --calls--> `seasonCupDefs()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/season_cups.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (59 total, 17 thin omitted)

### Community 0 - "col"
Cohesion: 0.08
Nodes (119): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, DailyBonusClaimBody, col(), newID(), getGameModesHandler(), selectGameModeHandler() (+111 more)

### Community 1 - "Hub"
Cohesion: 0.06
Nodes (44): BotRuntime, github.com/gorilla/websocket.Conn, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly() (+36 more)

### Community 2 - "matchmaking.go"
Cohesion: 0.08
Nodes (58): math/rand.Rand, TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), keysOf(), loadBotsNear(), makeBot(), makeBotName() (+50 more)

### Community 3 - "balance.go"
Cohesion: 0.07
Nodes (50): TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel(), levelFactor(), magazineFor() (+42 more)

### Community 4 - "missions.go"
Cohesion: 0.08
Nodes (48): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyBonusTier, DailyMissionDef, buildMissionsResponse(), MatchParticipant, MatchResultBody, MissionDifficulty, MissionMetric (+40 more)

### Community 5 - "build_arena.py"
Cohesion: 0.08
Nodes (43): ndarray, Random, border_rects(), build_map(), build_obstacles(), build_rooms(), circle_free(), _connected() (+35 more)

### Community 6 - "context.Context"
Cohesion: 0.10
Nodes (39): context.Context, go.mongodb.org/mongo-driver/bson.M, catalogPrice, cityPointsRow, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase() (+31 more)

### Community 7 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 8 - "withDB"
Cohesion: 0.17
Nodes (26): net/http/httptest.ResponseRecorder, ApplyMatchResult(), seasonCupCount(), reload(), seedRewardPlayer(), TestLosingDeductsTrophiesAndNothingElse(), TestTrophiesNeverGoNegativeOnALoss(), TestWinningPaysTrophiesCoinsAndXP() (+18 more)

### Community 9 - "testing.T"
Cohesion: 0.16
Nodes (24): testing.T, Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside() (+16 more)

### Community 10 - "RoundState"
Cohesion: 0.20
Nodes (8): time.Duration, Hub, rulesForMode(), spawnShieldFor(), ModeOfMatch(), TestRevengeRules(), RoundRules, RoundState

### Community 11 - "models.go"
Cohesion: 0.09
Nodes (23): AchievementDef, BuyRequest, ChatReadBody, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanMemberActionBody, ClanRespondBody (+15 more)

### Community 12 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 13 - "Arena"
Cohesion: 0.16
Nodes (8): clampF(), Arena, MapNameForMode(), parseArena(), arenaFile, Room, Arena, hashString()

### Community 14 - "NewHub"
Cohesion: 0.21
Nodes (19): NewHub(), Hub, newRound(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestRoundDurationIsSane(), TestRoundEndsOnlyOnce() (+11 more)

### Community 15 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 16 - "LoadArena"
Cohesion: 0.20
Nodes (18): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), addPlayer(), containsStr(), Hub, keysOfPlayers(), TestBotTargetsOnlyEnemiesInItsOwnMatch() (+10 more)

### Community 17 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 18 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 19 - "bot_sense_test.go"
Cohesion: 0.24
Nodes (15): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+7 more)

### Community 20 - "time.Time"
Cohesion: 0.22
Nodes (15): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, ChatMessageModel, ChatReadModel, ClanJoinRequestModel, DailyMissionDoc, FriendRequestModel, onlineStateFor() (+7 more)

### Community 21 - "applyLoadout"
Cohesion: 0.33
Nodes (10): addVictim(), bombHub(), Hub, TestApplyBombDamageIgnoresBadGeometry(), TestBombCooldownSurvivesRejoin(), TestBombRangeIsClamped(), TestBombRejectsNonFiniteInput(), TestBombZeroDirectionThrowsForward() (+2 more)

### Community 22 - "newBotHub"
Cohesion: 0.47
Nodes (8): blockedSpawnPair(), Hub, makeTestPlayer(), newBotHub(), TestBotIgnoresItsOwnTeam(), TestBotNavigatesWallsToReachThePlayer(), TestBotRespawnsSomewhereValid(), TestBotsLeaveWhenNoHumansRemain()

### Community 23 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 24 - "pathArena"
Cohesion: 0.46
Nodes (7): assertWalkable(), Arena, pathArena(), TestPathBetweenEverySpawnPair(), TestPathDoesNotWanderTheWholeMap(), TestPathFromPointHuggingAWall(), TestPathIsSmoothed()

### Community 25 - "bots_test.go"
Cohesion: 0.33
Nodes (6): contains(), TestBackfillWindowIsTwentySeconds(), TestBotIdentityNeverReachesTheClient(), TestBotProfilesAreCoherent(), TestBotRosterSizeIsInRange(), TestSkillProfilesAreOrdered()

### Community 26 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 27 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 28 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 29 - "ClanModel"
Cohesion: 0.50
Nodes (4): ClanMember, ClanModel, clanLeaderInfo(), cityLeaderboardEntry()

### Community 30 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 31 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 32 - "main"
Cohesion: 0.67
Nodes (3): net/http.HandlerFunc, corsMiddleware(), main()

### Community 33 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 34 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **47 isolated node(s):** `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody`, `SeasonCupClaimBody`, `SeasonPassBuyBody` (+42 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `Hub`, `matchmaking.go`, `balance.go`, `missions.go`, `context.Context`, `withDB`, `weekly_rewards.go`, `time.Time`?**
  _High betweenness centrality (0.096) - this node is a cross-community bridge._
- **Why does `Player` connect `Hub` to `testing.T`, `RoundState`, `models.go`, `LoadArena`, `bot_sense_test.go`, `time.Time`, `applyLoadout`, `newBotHub`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `balance.go`, `NewHub`, `time.Time`, `applyLoadout`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Are the 91 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `loadBotsNear()`) actually correct?**
  _`col()` has 91 INFERRED edges - model-reasoned connections that need verification._
- **Are the 46 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 46 INFERRED edges - model-reasoned connections that need verification._
- **What connects `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody` to the rest of the system?**
  _47 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.07936507936507936 - nodes in this community are weakly interconnected._