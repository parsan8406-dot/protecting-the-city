package main

// =============================================================================
// اسکین‌ها و ارتقای کاراکتر
// =============================================================================
//
// اسکین فقط ظاهر است: روی یک آیتمِ پایه (کاراکتر یا سلاح) می‌نشیند و تصویرش
// را عوض می‌کند، ولی تراز همیشه از خودِ آیتم پایه می‌آید. اسکین‌ها فقط از
// بتل‌پس به دست می‌آیند — هیچ‌وقت در shop_items نیستند و /buy_item هم آن‌ها
// را رد می‌کند.
//
// تصاویر سمت کلاینت (با همان شناسه‌ی اسکین):
//   سلاح      نمایشی  assets/weapons/<skin_id>.png
//             درون‌بازی assets/player_weapons/<skin_id>.png
//   کاراکتر   نمایشی  assets/characters/<skin_id>.png
//             درون‌بازی assets/player_characters/<skin_id>/
//
// ارتقا: هر کاراکتر از سطح ۱ تا سقفِ رده‌اش (balance.go → MaxLevelOf) با سکه
// ارتقا می‌یابد و CharacterStatsAtLevel همان سطح را در بازی اعمال می‌کند.

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/bson"
)

// SkinDef تعریف یک اسکین
type SkinDef struct {
	SkinID   string `json:"skin_id"`
	BaseID   string `json:"base_id"`  // آیتمی که اسکین رویش می‌نشیند
	Category string `json:"category"` // "character" | "weapon"
	Name     string `json:"name"`
	Rarity   string `json:"rarity"`
	// PassLevel پله‌ی مسیر طلایی بتل‌پس که این اسکین را می‌دهد
	PassLevel int `json:"pass_level"`
}

// SkinCatalog همه‌ی اسکین‌های بازی. اسکین جدید = یک سطر اینجا + تصاویرش.
var SkinCatalog = []SkinDef{
	{SkinID: "ak47_fire", BaseID: "ak47", Category: "weapon",
		Name: "AK-47 آتشین", Rarity: "legend", PassLevel: 10},
	{SkinID: "skin_default_red", BaseID: "skin_default", Category: "character",
		Name: "سرباز سرخ", Rarity: "legend", PassLevel: 20},
}

var skinByID = func() map[string]SkinDef {
	m := make(map[string]SkinDef, len(SkinCatalog))
	for _, s := range SkinCatalog {
		m[s.SkinID] = s
	}
	return m
}()

// isSkinID آیا این شناسه یک اسکین است (نه آیتم قابل خرید)
func isSkinID(id string) bool {
	_, ok := skinByID[id]
	return ok
}

// skinForPassLevel اسکینی که پله‌ی طلاییِ level می‌دهد (خالی یعنی هیچ)
func skinForPassLevel(level int) (SkinDef, bool) {
	for _, s := range SkinCatalog {
		if s.PassLevel == level {
			return s, true
		}
	}
	return SkinDef{}, false
}

func ownsSkin(p *PlayerModel, skinID string) bool {
	for _, id := range p.OwnedSkins {
		if id == skinID {
			return true
		}
	}
	return false
}

// activeSkin اسکینی که روی آیتم پایه‌ی baseID دیده می‌شود.
// اگر انتخاب نشده، مال بازیکن نیست یا به این آیتم نمی‌خورد، خالی برمی‌گردد
// و آیتم با ظاهر پیش‌فرض خودش نمایش داده می‌شود.
func activeSkin(p *PlayerModel, baseID string) string {
	if p == nil || baseID == "" {
		return ""
	}
	skinID := p.EquippedSkins[baseID]
	def, ok := skinByID[skinID]
	if !ok || def.BaseID != baseID || !ownsSkin(p, skinID) {
		return ""
	}
	return skinID
}

// ownsCharacter کاراکتر پیش‌فرض همیشه مال بازیکن است
func ownsCharacter(p *PlayerModel, characterID string) bool {
	if characterID == defaultCharacterID {
		return true
	}
	for _, id := range p.OwnedCharacters {
		if id == characterID {
			return true
		}
	}
	return false
}

func ownsWeapon(p *PlayerModel, weaponID string) bool {
	if weaponID == defaultWeaponID || weaponID == "pistol_default" {
		return true
	}
	for _, id := range p.OwnedWeapons {
		if id == weaponID {
			return true
		}
	}
	return false
}

// -----------------------------------------------------------------------------
// ارتقا
// -----------------------------------------------------------------------------

// upgradeCostPerLevel سکه‌ی هر قدم ارتقا به ازای سطح فعلی. قدم n→n+1 برابر
// n × این عدد است، پس هر سطح کمی گران‌تر از قبلی می‌شود.
var upgradeCostPerLevel = map[string]int{
	"rare":   800,
	"epic":   1200,
	"legend": 1600,
}

// characterLevel سطح ارتقای یک کاراکتر (حداقل ۱، حداکثر سقف رده)
func characterLevel(p *PlayerModel, characterID string) int {
	level := 1
	if p != nil {
		if lv, ok := p.ItemLevels[characterID]; ok && lv > 1 {
			level = lv
		}
	}
	if maxLv := MaxLevelOf(characterID); level > maxLv {
		level = maxLv
	}
	return level
}

// upgradeCost سکه‌ی لازم برای رفتن از level به level+1 (صفر یعنی در سقف است)
func upgradeCost(characterID string, level int) int {
	if level >= MaxLevelOf(characterID) {
		return 0
	}
	rarity, ok := characterRarity[characterID]
	if !ok {
		rarity = "rare"
	}
	return upgradeCostPerLevel[rarity] * level
}

func combatSummary(characterID string, level int) map[string]interface{} {
	s := CharacterStatsAtLevel(characterID, level)
	return map[string]interface{}{
		"health":      s.Health,
		"damage":      s.Damage,
		"bomb_damage": s.BombDamage,
		"heal_amount": s.HealAmount,
	}
}

// characterUpgradeView وضعیت ارتقای یک کاراکتر برای صفحه‌ی انتخاب
func characterUpgradeView(p *PlayerModel, characterID string) map[string]interface{} {
	level := characterLevel(p, characterID)
	maxLv := MaxLevelOf(characterID)
	view := map[string]interface{}{
		"item_id":   characterID,
		"level":     level,
		"max_level": maxLv,
		"owned":     ownsCharacter(p, characterID),
		"cost":      upgradeCost(characterID, level),
		"cost_type": "coins",
		"current":   combatSummary(characterID, level),
	}
	if level < maxLv {
		view["next"] = combatSummary(characterID, level+1)
	}
	return view
}

// allCharacterIDs همه‌ی کاراکترهای تراز شده، مرتب
func allCharacterIDs() []string {
	ids := make([]string, 0, len(characterRarity))
	for id := range characterRarity {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}

// -----------------------------------------------------------------------------
// GET /skins?username=
// -----------------------------------------------------------------------------

func skinsView(p *PlayerModel) []map[string]interface{} {
	out := make([]map[string]interface{}, 0, len(SkinCatalog))
	for _, s := range SkinCatalog {
		out = append(out, map[string]interface{}{
			"skin_id":    s.SkinID,
			"base_id":    s.BaseID,
			"category":   s.Category,
			"name":       s.Name,
			"rarity":     s.Rarity,
			"pass_level": s.PassLevel,
			"source":     "battle_pass",
			"owned":      ownsSkin(p, s.SkinID),
			"equipped":   activeSkin(p, s.BaseID) == s.SkinID,
		})
	}
	return out
}

func equippedSkinsView(p *PlayerModel) map[string]string {
	out := map[string]string{}
	for _, s := range SkinCatalog {
		if activeSkin(p, s.BaseID) == s.SkinID {
			out[s.BaseID] = s.SkinID
		}
	}
	return out
}

func getSkinsHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, err := getPlayerByUsername(ctx, r.URL.Query().Get("username"))
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	jsonResponse(w, map[string]interface{}{
		"skins":          skinsView(p),
		"equipped_skins": equippedSkinsView(p),
	})
}

// -----------------------------------------------------------------------------
// POST /skins/equip {username, skin_id, base_id}
// -----------------------------------------------------------------------------

// SkinEquipRequest skin_id خالی یعنی برگشت به ظاهر پیش‌فرضِ base_id
type SkinEquipRequest struct {
	Username string `json:"username"`
	SkinID   string `json:"skin_id"`
	BaseID   string `json:"base_id"`
}

func equipSkinHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req SkinEquipRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}

	baseID := req.BaseID
	var update bson.M
	if req.SkinID == "" {
		if baseID == "" {
			httpError(w, "آیتم مشخص نشده", http.StatusBadRequest)
			return
		}
		update = bson.M{"$unset": bson.M{"equipped_skins." + baseID: ""}}
	} else {
		def, ok := skinByID[req.SkinID]
		if !ok {
			httpError(w, "این اسکین وجود ندارد", http.StatusNotFound)
			return
		}
		if !ownsSkin(p, def.SkinID) {
			httpError(w, "این اسکین را هنوز از بتل‌پس نگرفته‌ای", http.StatusForbidden)
			return
		}
		baseID = def.BaseID
		if err := ensureMapField(ctx, p.PlayerID, "equipped_skins"); err != nil {
			httpError(w, "خطا در ثبت اسکین", http.StatusInternalServerError)
			return
		}
		set := bson.M{"equipped_skins." + baseID: def.SkinID}
		// انتخاب اسکین یعنی می‌خواهد با همان آیتم بازی کند
		if def.Category == "character" && ownsCharacter(p, baseID) {
			set["equipped_character"] = baseID
		} else if def.Category == "weapon" && ownsWeapon(p, baseID) {
			set["equipped_weapon"] = baseID
		}
		update = bson.M{"$set": set}
	}

	if _, err := col(ColPlayers).UpdateOne(ctx, bson.M{"player_id": p.PlayerID}, update); err != nil {
		httpError(w, "خطا در ثبت اسکین", http.StatusInternalServerError)
		return
	}

	fresh, err := getPlayerByID(ctx, p.PlayerID)
	if err != nil {
		httpError(w, "خطا در خواندن بازیکن", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, map[string]interface{}{
		"success":            true,
		"skins":              skinsView(fresh),
		"equipped_skins":     equippedSkinsView(fresh),
		"equipped_character": fresh.EquippedCharacter,
		"equipped_weapon":    fresh.EquippedWeapon,
	})
}

// -----------------------------------------------------------------------------
// GET /upgrades?username=   ·   POST /upgrade_character {username, item_id}
// -----------------------------------------------------------------------------

func getUpgradesHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, err := getPlayerByUsername(ctx, r.URL.Query().Get("username"))
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	list := make([]map[string]interface{}, 0, len(characterRarity))
	for _, id := range allCharacterIDs() {
		list = append(list, characterUpgradeView(p, id))
	}
	jsonResponse(w, map[string]interface{}{"characters": list, "coins": p.Coins})
}

// UpgradeRequest بدنه‌ی POST /upgrade_character
type UpgradeRequest struct {
	Username string `json:"username"`
	ItemID   string `json:"item_id"`
}

func upgradeCharacterHandler(w http.ResponseWriter, r *http.Request) {
	enableCORS(&w)
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}
	var req UpgradeRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}
	if _, ok := characterRarity[req.ItemID]; !ok {
		httpError(w, "این کاراکتر قابل ارتقا نیست", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	p, err := getPlayerByUsername(ctx, req.Username)
	if err != nil {
		httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		return
	}
	if !ownsCharacter(p, req.ItemID) {
		httpError(w, "اول باید این کاراکتر را داشته باشی", http.StatusForbidden)
		return
	}

	level := characterLevel(p, req.ItemID)
	cost := upgradeCost(req.ItemID, level)
	if cost <= 0 {
		httpError(w, "این کاراکتر به بالاترین سطح رسیده", http.StatusBadRequest)
		return
	}
	if p.Coins < cost {
		httpError(w, "سکه کافی نیست!", http.StatusBadRequest)
		return
	}

	if err := ensureMapField(ctx, p.PlayerID, "item_levels"); err != nil {
		httpError(w, "خطا در ارتقا", http.StatusInternalServerError)
		return
	}

	// اتمیک: فقط اگر هنوز همان سطح است و سکه کافی است. دو تپ پشت‌سرهم
	// نمی‌تواند دو بار پول بگیرد یا یک سطح را دو بار بدهد.
	levelKey := "item_levels." + req.ItemID
	levelMatch := bson.M{"$eq": level}
	if level == 1 {
		levelMatch = bson.M{"$in": bson.A{nil, 1}}
	}
	res, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": p.PlayerID, "coins": bson.M{"$gte": cost}, levelKey: levelMatch},
		bson.M{
			"$inc": bson.M{"coins": -cost},
			"$set": bson.M{levelKey: level + 1, "updated_at": time.Now()},
		})
	if err != nil {
		httpError(w, "خطا در ارتقا", http.StatusInternalServerError)
		return
	}
	if res.MatchedCount == 0 {
		httpError(w, "ارتقا انجام نشد: سکه کافی نیست یا سطح عوض شده", http.StatusConflict)
		return
	}

	fresh, err := getPlayerByID(ctx, p.PlayerID)
	if err != nil {
		httpError(w, "خطا در خواندن بازیکن", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, map[string]interface{}{
		"success":     true,
		"coins":       fresh.Coins,
		"gems":        fresh.Gems,
		"item_levels": fresh.ItemLevels,
		"upgrade":     characterUpgradeView(fresh, req.ItemID),
	})
}

// nonNilStrings تا JSON به‌جای null آرایه‌ی خالی بفرستد
func nonNilStrings(v []string) []string {
	if v == nil {
		return []string{}
	}
	return v
}

// ensureMapField فیلد null را به سند خالی تبدیل می‌کند تا $set روی
// «field.key» کار کند (مثل ensureArrayFields برای آرایه‌ها)
func ensureMapField(ctx context.Context, playerID, field string) error {
	_, err := col(ColPlayers).UpdateOne(ctx,
		bson.M{"player_id": playerID, field: bson.M{"$type": "null"}},
		bson.M{"$set": bson.M{field: bson.M{}}})
	return err
}

// PurgeSkinsFromShop اگر اسکینی به هر دلیل در shop_items افتاده باشد پاکش
// می‌کند — اسکین فقط از بتل‌پس می‌آید.
func PurgeSkinsFromShop(ctx context.Context) error {
	ids := make([]string, 0, len(SkinCatalog))
	for _, s := range SkinCatalog {
		ids = append(ids, s.SkinID)
	}
	_, err := col(ColShopItems).DeleteMany(ctx, bson.M{"item_id": bson.M{"$in": ids}})
	return err
}
