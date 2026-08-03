package main

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type ShopItem struct {
	ID       primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	ItemID   string             `bson:"item_id" json:"item_id"`
	Name     string             `bson:"name" json:"name"`
	Category string             `bson:"category" json:"category"`
	CostType string             `bson:"cost_type" json:"cost_type"`
	Price    int                `bson:"price" json:"price"`
}

type PlayerModel struct {
	ID                primitive.ObjectID `bson:"_id,omitempty" json:"id,omitempty"`
	Username          string             `bson:"username" json:"username"`
	Coins             int                `bson:"coins" json:"coins"`
	Gems              int                `bson:"gems" json:"gems"`
	Experience        int                `bson:"experience" json:"experience"`
	Level             int                `bson:"level" json:"level"`
	OwnedWeapons      []string           `bson:"owned_weapons" json:"owned_weapons"`
	OwnedCharacters   []string           `bson:"owned_characters" json:"owned_characters"`
	EquippedCharacter string             `bson:"equipped_character" json:"equipped_character"`
	EquippedWeapon    string             `bson:"equipped_weapon" json:"equipped_weapon"`
}

type EquipRequest struct {
	Username string `json:"username"`
	ItemID   string `json:"item_id"`
	Category string `json:"category"`
}

type BuyRequest struct {
	Username string `json:"username"`
	ItemID   string `json:"item_id"`
	Category string `json:"category"`
}

type Player struct {
	Username          string    `json:"username"`
	X                 float64   `json:"x"`
	Y                 float64   `json:"y"`
	Rot               float64   `json:"rot"`
	Character         string    `json:"character"`
	Weapon            string    `json:"weapon"`
	Health            int       `json:"health"`
	InvulnerableUntil time.Time `json:"-"`
	LastHealTime      time.Time `json:"-"`
	LastBombTime      time.Time `json:"-"`
}