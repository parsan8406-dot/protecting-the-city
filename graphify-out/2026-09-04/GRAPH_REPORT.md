# Graph Report - gun-game  (2026-09-04)

## Corpus Check
- 8 files · ~57,991 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 496 nodes · 1382 edges · 40 communities (28 shown, 12 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 325 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Community 0
- Community 1
- Community 2
- Community 3
- Community 4
- Community 5
- Community 6
- Community 7
- Community 8
- Community 9
- Community 10
- Community 11
- Community 12
- Community 13
- Community 14
- Community 15
- Community 16
- Community 17
- Community 18
- Community 19
- Community 20
- Community 21
- Community 22
- Community 23
- Community 24
- Community 28
- Community 29
- Community 30
- Community 31
- Community 32
- Community 33
- Community 34
- Community 36

## God Nodes (most connected - your core abstractions)
1. `col()` - 72 edges
2. `httpError()` - 43 edges
3. `Hub` - 41 edges
4. `enableCORS()` - 39 edges
5. `jsonResponse()` - 39 edges
6. `getPlayerByUsername()` - 32 edges
7. `PlayerModel` - 31 edges
8. `getChatOverviewHandler()` - 18 edges
9. `respondClanRequestHandler()` - 15 edges
10. `getPlayerByID()` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `broadcastChatMessage()` --calls--> `getClanByID()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/handlers_clan.go
- `getChatOverviewHandler()` --calls--> `getClanByID()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/handlers_clan.go
- `getChatOverviewHandler()` --calls--> `enableCORS()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/handlers.go
- `getLeaderboardHandler()` --calls--> `enableCORS()`  [INFERRED]
  gun_game_server/handlers_leaderboard.go → gun_game_server/handlers.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (40 total, 12 thin omitted)

### Community 0 - "Community 0"
Cohesion: 0.14
Nodes (73): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, BuyRequest, col(), newID(), buyItemHandler(), getChatHistoryHandler() (+65 more)

### Community 1 - "Community 1"
Cohesion: 0.07
Nodes (53): testing.T, TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), mustArena(), TestArenaLoads(), TestCenterIsFree(), TestLineOfSight(), TestNearestFreeEscapesWall() (+45 more)

### Community 2 - "Community 2"
Cohesion: 0.10
Nodes (29): github.com/gorilla/websocket.Conn, time.Duration, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly() (+21 more)

### Community 3 - "Community 3"
Cohesion: 0.08
Nodes (31): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, AchievementDef, ChatMessageModel, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody, ClanJoinBody (+23 more)

### Community 4 - "Community 4"
Cohesion: 0.14
Nodes (29): context.Context, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems(), MigratePlayers() (+21 more)

### Community 5 - "Community 5"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 6 - "Community 6"
Cohesion: 0.17
Nodes (21): go.mongodb.org/mongo-driver/bson.M, getLeaderboardHandler(), leaderboardEntry(), leaderboardFilter(), leaderboardPosition(), myLeaderboardStanding(), playerAheadOf(), seasonCupCount() (+13 more)

### Community 7 - "Community 7"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 8 - "Community 8"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 9 - "Community 9"
Cohesion: 0.18
Nodes (16): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, MatchParticipant, MatchRecord, MatchResultBody, MissionDifficulty, MissionMetric, applyMatchToMissions() (+8 more)

### Community 10 - "Community 10"
Cohesion: 0.21
Nodes (8): net/http.HandlerFunc, Arena, clampF(), LoadArena(), arenaFile, NewHub(), corsMiddleware(), main()

### Community 11 - "Community 11"
Cohesion: 0.23
Nodes (13): pickDailyMissions(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestMissionSecondsLeftRange(), TestPickDailyMissionsIsDeterministic(), TestPickDailyMissionsMetricVariety() (+5 more)

### Community 12 - "Community 12"
Cohesion: 0.29
Nodes (12): ndarray, greedy_rects(), main(), outside_mask(), pack_bits(), pick_spawns(), بسته‌بندی گرید به بیت (سطر-محور، کم‌ارزش‌ترین بیت اول) و سپس base64., نقاط شروع: خانه‌های آزادی که از هر دیواری فاصله‌ی امن دارند و پخش‌اند. (+4 more)

### Community 13 - "Community 13"
Cohesion: 0.30
Nodes (11): time.Time, DailyMissionDoc, buildMissionsResponse(), loadOrCreateDailyMissions(), missionDayEnd(), missionDayKey(), missionSecondsLeft(), repairMissionStates() (+3 more)

### Community 14 - "Community 14"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 15 - "Community 15"
Cohesion: 0.33
Nodes (5): levelFromExperience(), minInt(), MissionClaimBody, TestLevelFromExperience(), SeasonPassClaimBody

### Community 16 - "Community 16"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 17 - "Community 17"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 18 - "Community 18"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 19 - "Community 19"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 20 - "Community 20"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **39 isolated node(s):** `MissionClaimBody`, `SeasonPassClaimBody`, `https-proxy-agent`, `@qwen-code/sdk`, `net8.0` (+34 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `Community 0` to `Community 1`, `Community 2`, `Community 3`, `Community 4`, `Community 6`, `Community 9`, `Community 13`?**
  _High betweenness centrality (0.089) - this node is a cross-community bridge._
- **Why does `Hub` connect `Community 2` to `Community 0`, `Community 1`, `Community 10`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `Community 6` to `Community 0`, `Community 2`, `Community 3`, `Community 4`, `Community 13`?**
  _High betweenness centrality (0.050) - this node is a cross-community bridge._
- **Are the 61 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `buyItemHandler()`) actually correct?**
  _`col()` has 61 INFERRED edges - model-reasoned connections that need verification._
- **Are the 34 inferred relationships involving `httpError()` (e.g. with `getChatHistoryHandler()` and `getChatOverviewHandler()`) actually correct?**
  _`httpError()` has 34 INFERRED edges - model-reasoned connections that need verification._
- **What connects `MissionClaimBody`, `SeasonPassClaimBody`, `https-proxy-agent` to the rest of the system?**
  _39 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.14080656185919344 - nodes in this community are weakly interconnected._