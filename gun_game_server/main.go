package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// Global database reference
var db *mongo.Database

func main() {
	// 1. Load configuration from environment variables or use safe defaults
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017"
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// 2. Database Connection setup
	fmt.Println("Connecting to MongoDB...")
	clientOptions := options.Client().ApplyURI(mongoURI)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		log.Fatal("❌ Error connecting to MongoDB: ", err)
	}

	// Ping database to confirm the connection is active
	err = client.Ping(ctx, nil)
	if err != nil {
		log.Fatalf("❌ Cannot ping MongoDB: %v", err)
	}

	db = client.Database("gun_game_db")
	fmt.Println("✅ Successfully connected to MongoDB!")

	// 3. Initialize High-Performance Real-time WebSocket Hub
	hub := NewHub()
	go hub.Run()
	fmt.Println("✅ Real-time WebSocket Hub is running...")

	// 4. Register HTTP Endpoints
	http.HandleFunc("/get_player", getPlayerHandler)
	http.HandleFunc("/get_shop", getShopHandler)
	http.HandleFunc("/buy_item", buyItemHandler)
	http.HandleFunc("/equip_item", equipItemHandler)

	// WebSocket handler using the concurrent-safe Hub
	http.HandleFunc("/ws", func(w http.ResponseWriter, r *http.Request) {
		ServeWs(hub, w, r)
	})

	// 5. Start the web server
	addr := ":" + port
	fmt.Printf("🚀 Server is running on port %s, waiting for client connections...\n", port)

	server := &http.Server{
		Addr:         addr,
		WriteTimeout: 15 * time.Second,
		ReadTimeout:  15 * time.Second,
	}

	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("❌ Server error: %v", err)
	}
}
