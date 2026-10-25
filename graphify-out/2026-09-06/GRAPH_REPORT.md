# Graph Report - gun-game  (2026-09-05)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 528 nodes · 1469 edges · 38 communities (25 shown, 13 thin omitted)
- Extraction: 76% EXTRACTED · 24% INFERRED · 0% AMBIGUOUS · INFERRED: 351 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- testing.T
- col
- models.go
- Hub
- missions.go
- context.Context
- patch_scenes.py
- build_rig.py
- Row Sheet UI Asset Preview Page
- Arena
- handlers_leaderboard.go
- build_arena.py
- deform_check.py
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
- Player
- gun_game_server

## God Nodes (most connected - your core abstractions)
1. `col()` - 78 edges
2. `Hub` - 47 edges
3. `httpError()` - 45 edges
4. `enableCORS()` - 41 edges
5. `jsonResponse()` - 39 edges
6. `getPlayerByUsername()` - 33 edges
7. `PlayerModel` - 31 edges
8. `getChatOverviewHandler()` - 18 edges
9. `mustArena()` - 15 edges
10. `sendChatMessageHandler()` - 15 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `TestCheatingClientCannotInstantTurnToFire()` --calls--> `statsOf()`  [INFERRED]
  gun_game_server/anticheat_test.go → gun_game_server/hub.go
- `mustArena()` --calls--> `LoadArena()`  [INFERRED]
  gun_game_server/arena_test.go → gun_game_server/arena.go
- `getCharacterHealth()` --calls--> `CharacterStats()`  [INFERRED]
  gun_game_server/hub.go → gun_game_server/balance.go
- `statsOf()` --calls--> `CharacterStats()`  [INFERRED]
  gun_game_server/hub.go → gun_game_server/balance.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (38 total, 13 thin omitted)

### Community 0 - "testing.T"
Cohesion: 0.06
Nodes (75): Arena, testing.T, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly() (+67 more)

### Community 1 - "col"
Cohesion: 0.14
Nodes (75): go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, col(), newID(), getGameModesHandler(), selectGameModeHandler(), buyItemHandler() (+67 more)

### Community 2 - "models.go"
Cohesion: 0.05
Nodes (60): CharStats, go.mongodb.org/mongo-driver/bson/primitive.ObjectID, time.Time, AchievementDef, BuyRequest, ChatMessageModel, ChatReadBody, ChatReadModel (+52 more)

### Community 3 - "Hub"
Cohesion: 0.10
Nodes (21): github.com/gorilla/websocket.Conn, time.Duration, Client, SetPlayerOnline(), broadcastChatMessage(), Hub, distance(), equippedFor() (+13 more)

### Community 4 - "missions.go"
Cohesion: 0.10
Nodes (38): DailyMissionDef, DailyMissionDoc, buildMissionsResponse(), levelFromExperience(), minInt(), MatchParticipant, MissionClaimBody, MissionDifficulty (+30 more)

### Community 5 - "context.Context"
Cohesion: 0.14
Nodes (28): context.Context, go.mongodb.org/mongo-driver/mongo.IndexModel, catalogPrice, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase(), MergeDuplicateShopItems() (+20 more)

### Community 6 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 7 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 8 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 9 - "Arena"
Cohesion: 0.21
Nodes (8): net/http.HandlerFunc, Arena, clampF(), LoadArena(), arenaFile, NewHub(), corsMiddleware(), main()

### Community 10 - "handlers_leaderboard.go"
Cohesion: 0.32
Nodes (11): go.mongodb.org/mongo-driver/bson.M, leaderboardEntry(), leaderboardFilter(), leaderboardPosition(), myLeaderboardStanding(), playerAheadOf(), seasonCupCount(), seasonNumber() (+3 more)

### Community 11 - "build_arena.py"
Cohesion: 0.25
Nodes (10): ndarray, border_rects(), main(), pack_bits(), pick_spawns(), اندازه‌ی جهانی: عرض ثابت، ارتفاع از روی نسبت تصویر بک‌گراند., چهار دیوار دور زمین. بیرون از کادر گذاشته می‌شوند تا روی بک‌گراند نیفتند., بسته‌بندی گرید به بیت (سطر-محور، کم‌ارزش‌ترین بیت اول) و سپس base64. (+2 more)

### Community 12 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 13 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 14 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 15 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 16 - "Gun_Game"
Cohesion: 0.50
Nodes (4): net8.0, net9.0, Gun_Game, Godot.NET.Sdk/4.7.1

### Community 17 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **39 isolated node(s):** `SeasonRewardTier`, `https-proxy-agent`, `@qwen-code/sdk`, `net8.0`, `net9.0` (+34 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **13 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Hub` connect `Hub` to `testing.T`, `Arena`, `models.go`, `col`?**
  _High betweenness centrality (0.102) - this node is a cross-community bridge._
- **Why does `col()` connect `col` to `testing.T`, `models.go`, `Hub`, `missions.go`, `context.Context`, `handlers_leaderboard.go`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **Why does `PlayerModel` connect `models.go` to `col`, `handlers_leaderboard.go`, `Hub`?**
  _High betweenness centrality (0.053) - this node is a cross-community bridge._
- **Are the 67 inferred relationships involving `col()` (e.g. with `SeedCharacterStats()` and `ApplyMatchResult()`) actually correct?**
  _`col()` has 67 INFERRED edges - model-reasoned connections that need verification._
- **What connects `SeasonRewardTier`, `https-proxy-agent`, `@qwen-code/sdk` to the rest of the system?**
  _39 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `testing.T` be split into smaller, more focused modules?**
  _Cohesion score 0.056022408963585436 - nodes in this community are weakly interconnected._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.1389159363842908 - nodes in this community are weakly interconnected._