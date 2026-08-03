package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/mongo"
)

// Helper to write JSON error responses.
func httpError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": message})
}

// Helper to write standard JSON responses.
func jsonResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(data)
}

func getPlayerHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	username := r.URL.Query().Get("username")
	if username == "" {
		httpError(w, "یوزرنیم ارسال نشده", http.StatusBadRequest)
		return
	}

	playersCol := db.Collection("players")
	var player PlayerModel

	err := playersCol.FindOne(ctx, bson.M{"username": username}).Decode(&player)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			// Account doesn't exist, create default player
			player = PlayerModel{
				Username:          username,
				Coins:             1000,
				Gems:              50,
				Experience:        0,
				Level:             1,
				OwnedWeapons:      []string{"ak47", "pistol_default"},
				OwnedCharacters:   []string{"skin_default"},
				EquippedCharacter: "skin_default",
				EquippedWeapon:    "ak47",
			}

			_, err = playersCol.InsertOne(ctx, player)
			if err != nil {
				httpError(w, "خطا در ساخت اکانت جدید", http.StatusInternalServerError)
				return
			}
			fmt.Println("🌟 اکانت جدید در دیتابیس ساخته شد:", username)
		} else {
			httpError(w, "خطا در بازیابی اطلاعات بازیکن", http.StatusInternalServerError)
			return
		}
	}

	// Calculate level and display XP from total XP
	currentLevel := 1
	currentXp := player.Experience

	for {
		maxXp := currentLevel * 100
		if currentXp >= maxXp {
			currentXp -= maxXp
			currentLevel++
		} else {
			break
		}
	}

	finalMaxXp := currentLevel * 100

	// If level has increased, update in database
	if currentLevel != player.Level {
		player.Level = currentLevel
		_, _ = playersCol.UpdateOne(ctx, bson.M{"username": username}, bson.M{"$set": bson.M{"level": currentLevel}})
	}

	responseData := map[string]interface{}{
		"username":           player.Username,
		"coins":              player.Coins,
		"gems":               player.Gems,
		"level":              player.Level,
		"display_xp":         currentXp,
		"max_xp":             finalMaxXp,
		"owned_weapons":      player.OwnedWeapons,
		"owned_characters":   player.OwnedCharacters,
		"equipped_character": player.EquippedCharacter,
		"equipped_weapon":    player.EquippedWeapon,
	}

	jsonResponse(w, responseData)
}

func getShopHandler(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	cursor, err := db.Collection("shop_items").Find(ctx, bson.M{})
	if err != nil {
		httpError(w, "خطا در خواندن فروشگاه", http.StatusInternalServerError)
		return
	}
	defer cursor.Close(ctx)

	var items []ShopItem = make([]ShopItem, 0)
	if err = cursor.All(ctx, &items); err != nil {
		httpError(w, "خطا در پردازش لیست فروشگاه", http.StatusInternalServerError)
		return
	}

	jsonResponse(w, items)
}

func buyItemHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req BuyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	playersCol := db.Collection("players")
	var player PlayerModel
	err := playersCol.FindOne(ctx, bson.M{"username": req.Username}).Decode(&player)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		} else {
			httpError(w, "خطا در اتصال به پایگاه داده", http.StatusInternalServerError)
		}
		return
	}

	// 1. Handling coin pack purchases (costs gems)
	if req.Category == "coin_pack" {
		var costGems, rewardCoins int
		switch req.ItemID {
		case "coins_small":
			costGems = 10
			rewardCoins = 1000
		case "coins_medium":
			costGems = 45
			rewardCoins = 5000
		case "coins_large":
			costGems = 80
			rewardCoins = 10000
		default:
			httpError(w, "بسته سکه نامعتبر است", http.StatusBadRequest)
			return
		}

		if player.Gems < costGems {
			httpError(w, "جم کافی ندارید!", http.StatusBadRequest)
			return
		}

		_, err = playersCol.UpdateOne(ctx, bson.M{"username": req.Username}, bson.M{
			"$set": bson.M{
				"gems":  player.Gems - costGems,
				"coins": player.Coins + rewardCoins,
			},
		})
		if err != nil {
			httpError(w, "خطا در تراکنش دیتابیس", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
		return
	}

	// 2. Handling gem pack purchases (direct credits)
	if req.Category == "gem_pack" {
		var rewardGems int
		switch req.ItemID {
		case "gems_small":
			rewardGems = 50
		case "gems_medium":
			rewardGems = 250
		case "gems_large":
			rewardGems = 600
		default:
			httpError(w, "بسته جم نامعتبر است", http.StatusBadRequest)
			return
		}

		_, err = playersCol.UpdateOne(ctx, bson.M{"username": req.Username}, bson.M{
			"$set": bson.M{
				"gems": player.Gems + rewardGems,
			},
		})
		if err != nil {
			httpError(w, "خطا در شارژ جم", http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusOK)
		return
	}

	// 3. Handling regular shop items (weapons/characters)
	var item ShopItem
	err = db.Collection("shop_items").FindOne(ctx, bson.M{"item_id": req.ItemID}).Decode(&item)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			httpError(w, "آیتم پیدا نشد", http.StatusNotFound)
		} else {
			httpError(w, "خطا در خواندن آیتم", http.StatusInternalServerError)
		}
		return
	}

	ownedField := "owned_weapons"
	var ownedList []string
	if req.Category == "character" {
		ownedField = "owned_characters"
		ownedList = player.OwnedCharacters
	} else {
		ownedList = player.OwnedWeapons
	}

	// Check if already owned
	for _, id := range ownedList {
		if id == req.ItemID {
			httpError(w, "این آیتم را قبلاً خریده‌اید!", http.StatusBadRequest)
			return
		}
	}

	newCoins := player.Coins
	newGems := player.Gems

	if item.CostType == "coins" {
		if player.Coins < item.Price {
			httpError(w, "سکه کافی نیست!", http.StatusBadRequest)
			return
		}
		newCoins -= item.Price
	} else if item.CostType == "gems" {
		if player.Gems < item.Price {
			httpError(w, "جم کافی نیست!", http.StatusBadRequest)
			return
		}
		newGems -= item.Price
	}

	update := bson.M{
		"$set": bson.M{
			"coins": newCoins,
			"gems":  newGems,
		},
		"$push": bson.M{
			ownedField: req.ItemID,
		},
	}

	_, err = playersCol.UpdateOne(ctx, bson.M{"username": req.Username}, update)
	if err != nil {
		httpError(w, "خطا در ثبت خرید", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func equipItemHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpError(w, "فقط متد POST مجاز است", http.StatusMethodNotAllowed)
		return
	}

	var req EquipRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httpError(w, "دیتای ارسالی نامعتبر است", http.StatusBadRequest)
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	var player PlayerModel
	err := db.Collection("players").FindOne(ctx, bson.M{"username": req.Username}).Decode(&player)
	if err != nil {
		if err == mongo.ErrNoDocuments {
			httpError(w, "بازیکن پیدا نشد", http.StatusNotFound)
		} else {
			httpError(w, "خطا در پایگاه داده", http.StatusInternalServerError)
		}
		return
	}

	isOwned := false
	if req.Category == "character" {
		if req.ItemID == "skin_default" {
			isOwned = true
		} else {
			for _, item := range player.OwnedCharacters {
				if item == req.ItemID {
					isOwned = true
					break
				}
			}
		}
	} else if req.Category == "weapon" {
		if req.ItemID == "pistol_default" {
			isOwned = true
		} else {
			for _, item := range player.OwnedWeapons {
				if item == req.ItemID {
					isOwned = true
					break
				}
			}
		}
	}

	if !isOwned {
		httpError(w, "تقلب تشخیص داده شد: شما مالک این آیتم نیستید!", http.StatusForbidden)
		return
	}

	dbField := "equipped_weapon"
	if req.Category == "character" {
		dbField = "equipped_character"
	}

	update := bson.M{"$set": bson.M{dbField: req.ItemID}}
	_, err = db.Collection("players").UpdateOne(ctx, bson.M{"username": req.Username}, update)
	if err != nil {
		httpError(w, "خطا در ثبت اطلاعات", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
}
