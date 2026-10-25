# Graph Report - gun-game  (2026-09-05)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 515 nodes · 1424 edges · 41 communities (27 shown, 14 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 335 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- testing.T
- Hub
- context.Context
- models.go
- patch_scenes.py
- build_rig.py
- Row Sheet UI Asset Preview Page
- Arena
- missions.go
- buildSeasonPassResponse
- missions_test.go
- build_arena.py
- handlers_missions.go
- deform_check.py
- dependencies
- arm_angles.py
- solve
- Gun_Game
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
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- Player
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 72 edges
2. `Hub` - 47 edges
3. `httpError()` - 43 edges
4. `enableCORS()` - 39 edges
5. `jsonResponse()` - 39 edges
6. `getPlayerByUsername()` - 33 edges
7. `PlayerModel` - 31 edges
8. `getChatOverviewHandler()` - 18 edges
9. `sendChatMessageHandler()` - 15 edges
10. `respondClanRequestHandler()` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `SeedCharacterStats()` --calls--> `col()`  [INFERRED]
  gun_game_server/balance.go → gun_game_server/db.go
- `chatLastRead()` --calls--> `col()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/db.go
- `countChatUnread()` --calls--> `col()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/db.go
- `getChatOverviewHandler()` --calls--> `col()`  [INFERRED]
  gun_game_server/handlers_chat.go → gun_game_server/db.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (41 total, 14 thin omitted)

### Community 0 - "col"
Cohesion: 0.15
Nodes (71): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, BuyRequest, col(), newID(), buyItemHandler(), getChatHistoryHandler() (+63 more)

### Community 1 - "testing.T"
Cohesion: 0.06
Nodes (65): Arena, testing.T, TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), mustArena(), TestArenaHasNoObstacles(), TestArenaLoads(), TestInsideIsWalkable() (+57 more)

### Community 2 - "Hub"
Cohesion: 0.08
Nodes (34): CharStats, github.com/gorilla/websocket.Conn, time.Duration, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta() (+26 more)

### Community 3 - "context.Context"
Cohesion: 0.10
Nodes (43): context.Context, go.mongodb.org/mongo-driver/bson.M, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+35 more)

### Community 4 - "models.go"
Cohesion: 0.09
Nodes (34): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, ChatMessageModel, ChatReadBody, ChatReadModel, ChatSendBody, ClanCreateBody (+26 more)

### Community 5 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 6 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 7 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 8 - "Arena"
Cohesion: 0.21
Nodes (8): net/http.HandlerFunc, Arena, clampF(), LoadArena(), arenaFile, NewHub(), corsMiddleware(), main()

### Community 9 - "missions.go"
Cohesion: 0.21
Nodes (14): go.mongodb.org/mongo-driver/mongo.IndexModel, DailyMissionDef, MatchParticipant, MatchResultBody, MissionDifficulty, MissionMetric, applyMatchToMissions(), dailyMissionIndexes() (+6 more)

### Community 10 - "buildSeasonPassResponse"
Cohesion: 0.20
Nodes (14): buildSeasonPassResponse(), currentSeasonPass(), seasonPassLevelCost(), seasonPassProgress(), seasonPassTotalForLevel(), seasonPassXPRequired(), TestSeasonPassMaxLevelBarStaysFull(), TestSeasonPassProgress() (+6 more)

### Community 11 - "missions_test.go"
Cohesion: 0.23
Nodes (12): DailyMissionDoc, loadOrCreateDailyMissions(), missionDayKey(), missionSeed(), pickDailyMissions(), repairMissionStates(), TestMissionDayBoundary(), TestPickDailyMissionsIsDeterministic() (+4 more)

### Community 12 - "build_arena.py"
Cohesion: 0.25
Nodes (10): ndarray, border_rects(), main(), pack_bits(), pick_spawns(), اندازه‌ی جهانی: عرض ثابت، ارتفاع از روی نسبت تصویر بک‌گراند., چهار دیوار دور زمین. بیرون از کادر گذاشته می‌شوند تا روی بک‌گراند نیفتند., بسته‌بندی گرید به بیت (سطر-محور، کم‌ارزش‌ترین بیت اول) و سپس base64. (+2 more)

### Community 13 - "handlers_missions.go"
Cohesion: 0.24
Nodes (9): buildMissionsResponse(), levelFromExperience(), minInt(), MissionClaimBody, missionDayEnd(), missionSecondsLeft(), TestLevelFromExperience(), TestMissionSecondsLeftRange() (+1 more)

### Community 14 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 15 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 16 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 17 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 18 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 19 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **39 isolated node(s):** `MissionClaimBody`, `SeasonPassClaimBody`, `https-proxy-agent`, `@qwen-code/sdk`, `net8.0` (+34 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Hub` connect `Hub` to `Arena`, `testing.T`, `models.go`, `col`?**
  _High betweenness centrality (0.106) - this node is a cross-community bridge._
- **Why does `col()` connect `col` to `testing.T`, `Hub`, `context.Context`, `models.go`, `missions.go`, `missions_test.go`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `context.Context` to `col`, `Hub`, `models.go`, `buildSeasonPassResponse`, `PlayerStats`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **Are the 61 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `buyItemHandler()`) actually correct?**
  _`col()` has 61 INFERRED edges - model-reasoned connections that need verification._
- **What connects `MissionClaimBody`, `SeasonPassClaimBody`, `https-proxy-agent` to the rest of the system?**
  _39 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.14738738738738738 - nodes in this community are weakly interconnected._
- **Should `testing.T` be split into smaller, more focused modules?**
  _Cohesion score 0.06034801925212884 - nodes in this community are weakly interconnected._