# Graph Report - gun-game  (2026-09-20)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1252 nodes · 3792 edges · 73 communities (50 shown, 23 thin omitted)
- Extraction: 74% EXTRACTED · 26% INFERRED · 0% AMBIGUOUS · INFERRED: 995 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `42ec6210`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- col
- handlers_auth.go
- missions.go
- Hub
- withDB
- applyLoadout
- context.Context
- build_arena.py
- matchmaking.go
- testing.T
- models.go
- patch_scenes.py
- Player
- LoadArena
- PlayerModel
- bot_sense_test.go
- build_rig.py
- Hub
- RoundState
- demon_test.go
- RewardedAdsPlugin
- Row Sheet UI Asset Preview Page
- mustArena
- weekly_rewards.go
- time.Time
- .FindPath
- angleDiff
- abilities_test.go
- Hub
- Arena
- NewHub
- resetMM
- normalize_skin.py
- deform_check.py
- .teamRoomsFor
- make_wind_swirls.py
- dependencies
- arm_angles.py
- solve
- patrolPoint
- handlers_gift_codes.go
- PlayerStats
- prepare_chat_emojis.py
- strip_white_bg.py
- sweep_sniper.py
- layout_check.py
- scan_arms.py
- build.sh
- قانون تعادل: ۱۵ امتیاز در هر رده
- players.item_levels
- make_leaf_textures.py
- Godot_Plugin_GeminiGD
- Godot AI MIT License
- جدول قیمت بر اساس رده
- برتری رده: epic ۳٪ / legend ۶٪
- DemonState
- Hub
- DailyMissionDoc
- PlayerModel
- Hub
- DailyMissionDoc
- PlayerModel
- Arena
- CharStats
- MatchParticipant
- gun_game_server
- Player

## God Nodes (most connected - your core abstractions)
1. `col()` - 142 edges
2. `httpError()` - 76 edges
3. `enableCORS()` - 68 edges
4. `jsonResponse()` - 66 edges
5. `getPlayerByUsername()` - 51 edges
6. `PlayerModel` - 51 edges
7. `Hub` - 51 edges
8. `NewHub()` - 50 edges
9. `Player` - 41 edges
10. `RoundState` - 33 edges

## Surprising Connections (you probably didn't know these)
- `Row Sheet UI Asset Preview Page` --semantically_similar_to--> `Image Processing via Python Script, Not Context`  [INFERRED] [semantically similar]
  row_sheet.html → CLAUDE.md
- `buildSeasonCupsResponse()` --calls--> `currentSeasonCups()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/season_cups.go
- `buildSeasonCupsResponse()` --calls--> `seasonCupDefs()`  [INFERRED]
  gun_game_server/handlers_cups.go → gun_game_server/season_cups.go
- `ApplyMatchResult()` --calls--> `checkAndUnlockAchievements()`  [INFERRED]
  gun_game_server/game_modes.go → gun_game_server/achievements.go
- `SeedStaticData()` --calls--> `seedAchievements()`  [INFERRED]
  gun_game_server/db.go → gun_game_server/achievements.go

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Graphify Maintenance Workflow (query, update, scope rules)** — claude_graphify_first_policy, claude_graphify_out_directory, claude_graphify_update_command, claude_graph_update_threshold, claude_assets_exclusion_rule [EXTRACTED 1.00]
- **Mobile Touch UI Constraints** — claude_gun_game_mobile_shooter, claude_touch_scroll_requirement, claude_no_hover_rule, claude_ui_color_theme [EXTRACTED 1.00]
- **Context Budget Preservation Strategies** — claude_context_preservation_principle, claude_graphify_first_policy, claude_headroom_context_management, claude_headroom_desktop_limitation, claude_image_processing_policy [INFERRED 0.85]
- **Mission Row UI Composition** — row_sheet_mission_row_bg, row_sheet_fill_bar, row_sheet_allmissions_button, row_sheet_mission_ui_system [INFERRED 0.85]

## Communities (73 total, 23 thin omitted)

### Community 0 - "col"
Cohesion: 0.05
Nodes (166): AchievementDef, BuyRequest, go.mongodb.org/mongo-driver/mongo.Collection, net/http.Request, net/http.ResponseWriter, achievementMetrics(), buildAchievementView(), checkAndUnlockAchievements() (+158 more)

### Community 1 - "handlers_auth.go"
Cohesion: 0.07
Nodes (66): bufio.Scanner, net/http.HandlerFunc, guardStatus(), seedAuthPlayer(), TestProtectedAccountFlow(), TestSessionsAreCapped(), makeIDToken(), TestActingUsernamesReadsQueryAndBodyAndRestoresBody() (+58 more)

### Community 2 - "missions.go"
Cohesion: 0.05
Nodes (57): DailyMissionDoc, go.mongodb.org/mongo-driver/mongo.IndexModel, DailyBonusTier, DailyMissionDef, buildMissionsResponse(), minInt(), LiveObjective, buildObjectives() (+49 more)

### Community 3 - "Hub"
Cohesion: 0.08
Nodes (29): github.com/gorilla/websocket.Conn, time.Duration, Arena, BotSeat, Client, SetPlayerOnline(), broadcastChatMessage(), equippedFor() (+21 more)

### Community 4 - "withDB"
Cohesion: 0.09
Nodes (50): net/http/httptest.ResponseRecorder, coinsOf(), postJSON(), seedClaimPlayer(), TestDailyChestClaimWorksWhenBonusClaimedIsNull(), TestNewDayRecordIsBornWithAnArray(), TestSeasonChallengeClaimWorksWhenClaimedChallengesIsNull(), TestSeasonTierClaimWorksWhenClaimedLevelsIsNull() (+42 more)

### Community 5 - "applyLoadout"
Cohesion: 0.07
Nodes (48): go.mongodb.org/mongo-driver/bson.M, TestBombStockIsThreePerMatch(), TestFireCooldownIsAlwaysPositive(), TestMissChanceAndFireConeCanActuallyReject(), avgPip(), characterCombatDoc(), CharacterStats(), CharacterStatsAtLevel() (+40 more)

### Community 6 - "context.Context"
Cohesion: 0.07
Nodes (46): context.Context, catalogPrice, cityPointsRow, currencyPack, EnsureCollections(), EnsureIndexes(), GenerateUniquePlayerID(), InitDatabase() (+38 more)

### Community 7 - "build_arena.py"
Cohesion: 0.07
Nodes (48): ndarray, Random, border_rects(), build_arena_layout(), build_map(), build_obstacles(), build_rooms(), circle_free() (+40 more)

### Community 8 - "matchmaking.go"
Cohesion: 0.12
Nodes (36): math/rand.Rand, keysOf(), loadBotsNear(), makeBot(), makeBotName(), pickBotsNear(), seedBots(), myRankCard() (+28 more)

### Community 9 - "testing.T"
Cohesion: 0.09
Nodes (34): testing.T, shopRating(), TestPipsRespectRarityRange(), TestRarityAdvantageStaysSmall(), TestRarityTableCoversEveryCharacter(), TestResolvedStatsStayInSaneBounds(), TestSameRaritySharesSamePipBudget(), TestShopRatingGapStaysSmallAcrossRarities() (+26 more)

### Community 10 - "models.go"
Cohesion: 0.07
Nodes (27): AchievementDef, BuyRequest, ChatReadBody, ChatSendBody, ClanCreateBody, ClanJoinBody, ClanMember, ClanMemberActionBody (+19 more)

### Community 11 - "patch_scenes.py"
Cohesion: 0.15
Nodes (29): anim_idle(), anim_library(), anim_reset(), anim_shoot(), anim_subresource(), anim_walk(), bones_str(), build_bone_body() (+21 more)

### Community 12 - "Player"
Cohesion: 0.18
Nodes (13): Arena, CharStats, arenaOf(), Hub, Hub, turnStep(), BotRuntime, botSkillProfile (+5 more)

### Community 13 - "LoadArena"
Cohesion: 0.14
Nodes (27): TestHitActionIsRateLimited(), ArenaForMode(), LoadArena(), MapNameForMode(), addPlayer(), containsStr(), Hub, keysOfPlayers() (+19 more)

### Community 14 - "PlayerModel"
Cohesion: 0.15
Nodes (23): MaxLevelOf(), PlayerModel, PlayerSeasonCups, RecentMatch, currentSeasonCups(), SkinDef, SkinEquipRequest, activeSkin() (+15 more)

### Community 15 - "bot_sense_test.go"
Cohesion: 0.17
Nodes (23): Hub, senseHub(), TestBotDoesNotSeeBehindItself(), TestBotDoesNotSeeBeyondVisionRange(), TestBotDoesNotSeeThroughWalls(), TestBotDoesNotSenseAcrossMatches(), TestBotFacesTheDirectionItWalks(), TestBotIgnoresFriendlyGunfire() (+15 more)

### Community 16 - "build_rig.py"
Cohesion: 0.17
Nodes (22): arm_weights(), body_alpha(), body_cut_y(), body_weights(), build_part(), densify(), interior(), main() (+14 more)

### Community 17 - "Hub"
Cohesion: 0.16
Nodes (10): abilityKey(), bombStockKey(), canBeHurt(), Hub, isGuarded(), laserSegment(), laserTickDamage(), refreshAbilityTimers() (+2 more)

### Community 18 - "RoundState"
Cohesion: 0.21
Nodes (5): Hub, Player, RoundRules, RoundState, LiveObjective

### Community 19 - "demon_test.go"
Cohesion: 0.17
Nodes (20): absF(), Arena, mustBanishArena(), newDemonRound(), TestBanishArenaIsOpen(), TestBlastSpotStaysNearTheDemon(), TestBlastWarnsBeforeItDetonates(), TestDemonDiesWithEqualDamageIsADraw() (+12 more)

### Community 20 - "RewardedAdsPlugin"
Cohesion: 0.15
Nodes (9): android.os.Handler, RewardedAdsPlugin, com.adivery.sdk.AdiveryListener, org.godotengine.godot.Godot, org.godotengine.godot.plugin.GodotPlugin, org.godotengine.godot.plugin.SignalInfo, org.godotengine.godot.plugin.UsedByGodot, Override (+1 more)

### Community 21 - "Row Sheet UI Asset Preview Page"
Cohesion: 0.13
Nodes (20): assets/ Exclusion from the Graph, Context Preservation Principle, Graph Update Significance Threshold, Graphify-First Structural Query Policy, graphify-out/ Prebuilt Graph Output, graphify . --update (Incremental Graph Update), Gun Game (Mobile Shooter Project), Headroom Context Management (+12 more)

### Community 22 - "mustArena"
Cohesion: 0.19
Nodes (18): Arena, mustArena(), TestArenaHasInteriorWalls(), TestArenaLoads(), TestLineOfSight(), TestMostOfTheArenaIsWalkable(), TestNearestFreeEscapesOutside(), TestOutsideIsBlocked() (+10 more)

### Community 23 - "weekly_rewards.go"
Cohesion: 0.21
Nodes (17): createWeeklyRun(), payWeeklyRun(), persianDigits(), runWeeklyRewards(), StartWeeklyRewardLoop(), TestPersianDigits(), TestWeeklyRewardsOnlyTopThree(), TestWeekStartIsSaturdayMidnight() (+9 more)

### Community 24 - "time.Time"
Cohesion: 0.18
Nodes (16): go.mongodb.org/mongo-driver/bson/primitive.ObjectID, sync.Mutex, time.Time, ChatMessageModel, ChatReadModel, ClanJoinRequestModel, DailyMissionDoc, FriendRequestModel (+8 more)

### Community 25 - ".FindPath"
Cohesion: 0.19
Nodes (4): Arena, PathPoint, pfNode, pfQueue

### Community 26 - "angleDiff"
Cohesion: 0.28
Nodes (12): BotRuntime, isCloseAngle(), radToDegT(), TestCheatingClientCannotInstantTurnToFire(), TestClampRotationHandlesWrapBoundary(), TestClampRotationNeverExceedsMaxDelta(), TestClampRotationReachesCloseTargetsExactly(), Player (+4 more)

### Community 27 - "abilities_test.go"
Cohesion: 0.31
Nodes (15): abilityClient(), abilityPlayer(), corridorFree(), Arena, Hub, openCorridor(), runLaser(), TestGuardBlocksShotsAndBombs() (+7 more)

### Community 28 - "Hub"
Cohesion: 0.23
Nodes (4): Arena, Hub, newDemon(), DemonState

### Community 29 - "Arena"
Cohesion: 0.27
Nodes (5): Arena, clampF(), parseArena(), arenaFile, Room

### Community 30 - "NewHub"
Cohesion: 0.33
Nodes (13): NewHub(), Hub, newRound(), TestADrawMakesEveryoneAWinner(), TestDeadlineAccountsForWarmup(), TestDoubleDeathDoesNotEndRoundEarly(), TestLastTeamStandingWins(), TestOnlyTheWinningTeamWinsANormalRound() (+5 more)

### Community 31 - "resetMM"
Cohesion: 0.39
Nodes (11): TestFreshMatchesSurviveTheSweep(), TestLeavingAMatchFreesItsBots(), TestStaleMatchesAreSweptEventually(), busyNamesLocked(), ReleaseMatch(), sweepStaleMatchesLocked(), resetMM(), seedMatch() (+3 more)

### Community 32 - "normalize_skin.py"
Cohesion: 0.36
Nodes (10): backup(), character(), ensure_gdignore(), fit(), heavy_end(), main(), left' or 'right': which half of the silhouette holds more pixels., centroid, principal angle (deg), length along / across that axis. (+2 more)

### Community 33 - "deform_check.py"
Cohesion: 0.42
Nodes (8): deform(), globals_for(), parent_of(), pose: {bone_path: {'rot':..,'pos':(x,y),'scale':(sx,sy)}}, report(), rest_pos(), to_pl(), xform()

### Community 34 - ".teamRoomsFor"
Cohesion: 0.43
Nodes (3): Room, Arena, hashString()

### Community 35 - "make_wind_swirls.py"
Cohesion: 0.36
Nodes (7): build(), draw_strand(), خطوطِ پیچانِ باد: سه بافتِ «وزش» می‌سازد. شکلِ مرجع: چند خطِ کشیده که با هم…, یک رشته: موجِ کشیده‌ای که سرش در یک مارپیچ جمع می‌شود., شکلِ رشته در d_alpha و «کجای خط»بودنِ هر پیکسل در d_par., smoothstep(), strand()

### Community 36 - "dependencies"
Cohesion: 0.33
Nodes (5): https-proxy-agent, dependencies, https-proxy-agent, @qwen-code/sdk, @qwen-code/sdk

### Community 37 - "arm_angles.py"
Cohesion: 0.53
Nodes (5): hand_of(), main(), Centroid of the wrist/hand end of the arm, in placed (shifted) coords., skins(), solve()

### Community 38 - "solve"
Cohesion: 0.47
Nodes (5): hand_of(), T = art-px translation of the mesh from its current (shifted) place., LeftArm back to art-left (screen right), RightArm to art-right (screen left)., solve(), swapped()

### Community 39 - "patrolPoint"
Cohesion: 0.40
Nodes (3): Arena, BotRuntime, patrolPoint()

### Community 40 - "handlers_gift_codes.go"
Cohesion: 0.40
Nodes (4): createGiftCodeRequest, GiftCode, randomGiftCode(), redeemGiftCodeRequest

### Community 42 - "prepare_chat_emojis.py"
Cohesion: 0.50
Nodes (4): Image, main(), process(), آماده‌سازی ایموجی‌های چت برای بازی. عکس‌های خام (۱۲۵۴×۱۲۵۴، اکثراً با…

### Community 43 - "strip_white_bg.py"
Cohesion: 0.50
Nodes (3): Path, پس‌زمینه‌ی سفیدِ لوگوهای مود را شفاف می‌کند و اندازه را به ۵۱۲ می‌رساند. python…, strip()

### Community 44 - "sweep_sniper.py"
Cohesion: 0.83
Nodes (3): main(), render(), score()

## Knowledge Gaps
- **50 isolated node(s):** `SeasonCupClaimBody`, `adRewardRequest`, `DailyBonusClaimBody`, `MissionClaimBody`, `SeasonChallengeClaimBody` (+45 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **23 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `col()` connect `col` to `handlers_auth.go`, `Hub`, `withDB`, `applyLoadout`, `context.Context`, `matchmaking.go`, `weekly_rewards.go`?**
  _High betweenness centrality (0.114) - this node is a cross-community bridge._
- **Why does `RoundState` connect `RoundState` to `missions.go`, `LoadArena`, `demon_test.go`, `time.Time`, `angleDiff`, `Hub`, `NewHub`?**
  _High betweenness centrality (0.056) - this node is a cross-community bridge._
- **Why does `Hub` connect `Hub` to `col`, `applyLoadout`, `Player`, `time.Time`, `angleDiff`, `NewHub`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Are the 132 inferred relationships involving `col()` (e.g. with `checkAndUnlockAchievements()` and `loadAchievementDefs()`) actually correct?**
  _`col()` has 132 INFERRED edges - model-reasoned connections that need verification._
- **Are the 67 inferred relationships involving `httpError()` (e.g. with `getGameModesHandler()` and `selectGameModeHandler()`) actually correct?**
  _`httpError()` has 67 INFERRED edges - model-reasoned connections that need verification._
- **What connects `SeasonCupClaimBody`, `adRewardRequest`, `DailyBonusClaimBody` to the rest of the system?**
  _50 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `col` be split into smaller, more focused modules?**
  _Cohesion score 0.052324088341037495 - nodes in this community are weakly interconnected._