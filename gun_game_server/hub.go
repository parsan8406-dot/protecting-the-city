package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 4096
	maxShootRange  = 600.0
	hitDamage      = 25
	gracePeriod    = 3 * time.Second
	healCooldown   = 12 * time.Second
	healAmount     = 25
	bombCooldown   = 5 * time.Second
	bombDamage     = 50
	bombRange      = 300.0
	bombRadius     = 100.0
	bombDelay      = 1 * time.Second
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

func getWeaponDelay(weaponID string) time.Duration {
	switch weaponID {
	case "pistol_default":
		return 500 * time.Millisecond
	case "ak47":
		return 200 * time.Millisecond
	case "rifle_m4":
		return 250 * time.Millisecond
	case "sniper_awp":
		return 1000 * time.Millisecond
	default:
		return 300 * time.Millisecond
	}
}

type WSMessage struct {
	Type       string                 `json:"type"`
	Username   string                 `json:"username,omitempty"`
	Target     string                 `json:"target,omitempty"`
	X          float64                `json:"x,omitempty"`
	Y          float64                `json:"y,omitempty"`
	Rot        float64                `json:"rot,omitempty"`
	CharID     string                 `json:"character,omitempty"`
	Weapon     string                 `json:"weapon,omitempty"`
	Health     int                    `json:"health,omitempty"`
	Seconds    int                    `json:"seconds,omitempty"`
	DirectionX float64                `json:"dir_x,omitempty"`
	DirectionY float64                `json:"dir_y,omitempty"`
	RawData    map[string]interface{} `json:"-"`
}

type Client struct {
	hub       *Hub
	conn      *websocket.Conn
	send      chan []byte
	username  string
	lastShoot time.Time
}

type Hub struct {
	clients    map[*Client]bool
	players    map[string]*Player
	register   chan *Client
	unregister chan *Client
	broadcast  chan []byte
	actions    chan hubAction
}

type hubAction struct {
	client *Client
	msg    WSMessage
}

func NewHub() *Hub {
	return &Hub{
		clients:    make(map[*Client]bool),
		players:    make(map[string]*Player),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		broadcast:  make(chan []byte),
		actions:    make(chan hubAction, 1000),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case client := <-h.register:
			h.clients[client] = true
		case client := <-h.unregister:
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				if client.username != "" {
					delete(h.players, client.username)
					fmt.Printf("🔌 Player disconnected: %s\n", client.username)
					h.broadcastPlayerUpdate()
				}
			}
		case message := <-h.broadcast:
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					close(client.send)
					delete(h.clients, client)
				}
			}
		case action := <-h.actions:
			h.handleAction(action.client, action.msg)
		}
	}
}

func getCharacterHealth(characterID string) int {
	switch characterID {
	case "skin_default":
		return 75
	case "skin_heavy":
		return 150
	case "skin_fast":
		return 75
	default:
		return 100
	}
}

func distance(x1, y1, x2, y2 float64) float64 {
	dx := x2 - x1
	dy := y2 - y1
	return math.Sqrt(dx*dx + dy*dy)
}

func (h *Hub) validateHit(shooter *Player, targetUsername string) bool {
	targetPlayer, exists := h.players[targetUsername]
	if !exists {
		return false
	}
	if time.Now().Before(targetPlayer.InvulnerableUntil) {
		fmt.Printf("🛡️ Hit rejected: %s is invulnerable\n", targetUsername)
		return false
	}
	if time.Now().Before(shooter.InvulnerableUntil) {
		fmt.Printf("🛡️ Hit rejected: %s is in grace period\n", shooter.Username)
		return false
	}
	dist := distance(shooter.X, shooter.Y, targetPlayer.X, targetPlayer.Y)
	if dist > maxShootRange {
		fmt.Printf("❌ Hit rejected: Too far (%.2f > %.2f)\n", dist, maxShootRange)
		return false
	}
	fmt.Printf("✅ Hit validated! %s -> %s (Distance: %.2f)\n", shooter.Username, targetUsername, dist)
	return true
}

func (h *Hub) handleAction(client *Client, msg WSMessage) {
	switch msg.Type {
	case "join":
		if msg.Username == "" {
			return
		}
		client.username = msg.Username
		maxHealth := getCharacterHealth(msg.CharID)
		h.players[msg.Username] = &Player{
			Username:          msg.Username,
			X:                 0,
			Y:                 0,
			Rot:               0.0,
			Character:         msg.CharID,
			Weapon:            msg.Weapon,
			Health:            maxHealth,
			InvulnerableUntil: time.Now().Add(gracePeriod),
			LastHealTime:      time.Time{},
			LastBombTime:      time.Time{},
		}
		fmt.Printf("🎮 Player joined: %s (Char: %s, Weapon: %s, HP: %d)\n", msg.Username, msg.CharID, msg.Weapon, maxHealth)
		h.broadcastCountdown(3)
		go func(username string) {
			time.Sleep(gracePeriod)
			h.broadcastGameStart()
			fmt.Printf("⚔️ Grace period ended for: %s\n", username)
		}(msg.Username)
		h.broadcastPlayerUpdate()

	case "move":
		if client.username == "" {
			return
		}
		if p, exists := h.players[client.username]; exists {
			p.X = msg.X
			p.Y = msg.Y
			p.Rot = msg.Rot
			h.broadcastMove(client.username, msg.X, msg.Y, msg.Rot)
		}

	case "shoot":
		if client.username == "" {
			return
		}
		shooter, exists := h.players[client.username]
		if !exists {
			return
		}
		weaponDelay := getWeaponDelay(shooter.Weapon)
		if time.Since(client.lastShoot) < weaponDelay {
			return
		}
		client.lastShoot = time.Now()
		h.broadcastShoot(client.username, msg.X, msg.Y, msg.Rot)

	case "hit":
		if client.username == "" {
			return
		}
		shooter, exists := h.players[client.username]
		if !exists {
			return
		}
		if msg.Target == "" {
			return
		}
		if !h.validateHit(shooter, msg.Target) {
			return
		}
		if targetPlayer, exists := h.players[msg.Target]; exists {
			targetPlayer.Health -= hitDamage
			fmt.Printf("🔫 Hit! %s -> %s, HP: %d\n", client.username, msg.Target, targetPlayer.Health)
			if targetPlayer.Health <= 0 {
				targetPlayer.Health = 0
				h.broadcastHealth(msg.Target, 0)
				h.broadcastDeath(msg.Target)
				fmt.Printf("💀 Player died: %s\n", msg.Target)
			} else {
				h.broadcastHealth(msg.Target, targetPlayer.Health)
			}
		}

	case "heal":
		if client.username == "" {
			return
		}
		player, exists := h.players[client.username]
		if !exists {
			return
		}
		if player.Health <= 0 {
			fmt.Printf("❌ Heal rejected: %s is dead\n", client.username)
			return
		}
		maxHealth := getCharacterHealth(player.Character)
		if player.Health >= maxHealth {
			fmt.Printf("❌ Heal rejected: %s health is full\n", client.username)
			return
		}
		if !player.LastHealTime.IsZero() && time.Since(player.LastHealTime) < healCooldown {
			fmt.Printf("❌ Heal rejected: %s on cooldown\n", client.username)
			return
		}
		player.LastHealTime = time.Now()
		player.Health += healAmount
		if player.Health > maxHealth {
			player.Health = maxHealth
		}
		fmt.Printf("🏥 Heal! %s -> HP: %d/%d\n", client.username, player.Health, maxHealth)
		h.broadcastHealSuccess(client.username, player.Health)
		h.broadcastHealCooldown(client.username)

	case "bomb":
		if client.username == "" {
			return
		}
		player, exists := h.players[client.username]
		if !exists {
			fmt.Printf("❌ Bomb rejected: player not found\n")
			return
		}
		if player.Health <= 0 {
			fmt.Printf("❌ Bomb rejected: %s is dead\n", client.username)
			return
		}
		if !player.LastBombTime.IsZero() && time.Since(player.LastBombTime) < bombCooldown {
			fmt.Printf("❌ Bomb rejected: %s on cooldown\n", client.username)
			return
		}
		player.LastBombTime = time.Now()
		dirX := msg.DirectionX
		dirY := msg.DirectionY
		dirLen := math.Sqrt(dirX*dirX + dirY*dirY)
		if dirLen > 0 {
			dirX /= dirLen
			dirY /= dirLen
		}
		expX := player.X + dirX*bombRange
		expY := player.Y + dirY*bombRange
		fmt.Printf("💣 Bomb by %s! Target: (%.2f, %.2f)\n", client.username, expX, expY)
		h.broadcastBombThrown(client.username, player.X, player.Y, expX, expY, bombRadius)
		go func(ex, ey float64) {
			time.Sleep(bombDelay)
			h.applyBombDamage(ex, ey, bombRadius, bombDamage)
		}(expX, expY)
	}
}

// ✅ جدید:
func (h *Hub) applyBombDamage(expX, expY, radius float64, damage int) {
	fmt.Printf("💥 Bomb exploded at (%.2f, %.2f) with radius %.2f\n", expX, expY, radius)

	// broadcast انفجار به همه
	h.broadcastBombExplosion(expX, expY, radius)

	// بررسی بازیکن‌های در محدوده انفجار
	for username, player := range h.players {
		if player.Health <= 0 {
			fmt.Printf("⚠️ %s is dead, skipping\n", username)
			continue
		}

		// چک محافظت
		if time.Now().Before(player.InvulnerableUntil) {
			fmt.Printf("🛡️ %s is invulnerable, skipping bomb damage\n", username)
			continue
		}

		dist := distance(expX, expY, player.X, player.Y)
		fmt.Printf("🔍 Checking %s: distance=%.2f, radius=%.2f, in_range=%v\n",
			username, dist, radius, dist <= radius)

		if dist <= radius {
			player.Health -= damage
			fmt.Printf("💥 %s hit by bomb! Distance: %.2f, New Health: %d\n",
				username, dist, player.Health)

			if player.Health <= 0 {
				player.Health = 0
				h.broadcastHealth(username, 0)
				h.broadcastDeath(username)
				fmt.Printf("💀 Player died from bomb: %s\n", username)
			} else {
				h.broadcastHealth(username, player.Health)
			}
		} else {
			fmt.Printf("✅ %s is safe (too far)\n", username)
		}
	}
}

func (h *Hub) broadcastPlayerUpdate() {
	data := map[string]interface{}{"type": "update_players", "players": h.players}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastMove(username string, x, y, rot float64) {
	data := map[string]interface{}{"type": "move", "username": username, "x": x, "y": y, "rot": rot}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastShoot(shooter string, x, y, rot float64) {
	data := map[string]interface{}{"type": "shoot", "username": shooter, "x": x, "y": y, "rot": rot}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastHealth(target string, health int) {
	data := map[string]interface{}{"type": "health_update", "username": target, "health": health}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastDeath(target string) {
	data := map[string]interface{}{"type": "die", "username": target}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastCountdown(seconds int) {
	data := map[string]interface{}{"type": "countdown", "seconds": seconds}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastGameStart() {
	data := map[string]interface{}{"type": "game_start"}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastHealSuccess(username string, newHealth int) {
	data := map[string]interface{}{"type": "heal_success", "username": username, "health": newHealth}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastHealCooldown(username string) {
	data := map[string]interface{}{"type": "heal_cooldown", "username": username}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastBombThrown(shooter string, startX, startY, expX, expY, radius float64) {
	data := map[string]interface{}{
		"type":        "bomb_thrown",
		"username":    shooter,
		"start_x":     startX,
		"start_y":     startY,
		"explosion_x": expX,
		"explosion_y": expY,
		"bomb_radius": radius,
	}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) broadcastBombExplosion(expX, expY, radius float64) {
	data := map[string]interface{}{
		"type":             "bomb_explosion",
		"explosion_x":      expX,
		"explosion_y":      expY,
		"explosion_radius": radius,
	}
	bytes, _ := json.Marshal(data)
	h.queueBroadcast(bytes)
}

func (h *Hub) queueBroadcast(message []byte) {
	for client := range h.clients {
		select {
		case client.send <- message:
		default:
			close(client.send)
			delete(h.clients, client)
		}
	}
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()
	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})
	for {
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}
		var raw map[string]interface{}
		if err := json.Unmarshal(message, &raw); err != nil {
			continue
		}
		msg := WSMessage{RawData: raw}
		if t, ok := raw["type"].(string); ok {
			msg.Type = t
		}
		if u, ok := raw["username"].(string); ok {
			msg.Username = u
		}
		if tgt, ok := raw["target"].(string); ok {
			msg.Target = tgt
		}
		if xVal, ok := raw["x"].(float64); ok {
			msg.X = xVal
		}
		if yVal, ok := raw["y"].(float64); ok {
			msg.Y = yVal
		}
		if rVal, ok := raw["rot"].(float64); ok {
			msg.Rot = rVal
		}
		if cVal, ok := raw["character"].(string); ok {
			msg.CharID = cVal
		}
		if wVal, ok := raw["weapon"].(string); ok {
			msg.Weapon = wVal
		}
		if dxVal, ok := raw["dir_x"].(float64); ok {
			msg.DirectionX = dxVal
		}
		if dyVal, ok := raw["dir_y"].(float64); ok {
			msg.DirectionY = dyVal
		}
		c.hub.actions <- hubAction{client: c, msg: msg}
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)
			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}
			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("upgrade error:", err)
		return
	}
	client := &Client{hub: hub, conn: conn, send: make(chan []byte, 256)}
	client.hub.register <- client
	go client.writePump()
	go client.readPump()
}
