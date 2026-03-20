package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type response struct {
	Service   string `json:"service"`
	Status    string `json:"status"`
	Payment   string `json:"payment"`
	Timestamp string `json:"timestamp"`
}

func main() {
	paymentURL := os.Getenv("PAYMENT_URL")
	if paymentURL == "" {
		paymentURL = "http://payment"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		resp, err := http.Get(paymentURL)
		paymentStatus := "unavailable"
		if err == nil {
			defer resp.Body.Close()
			if resp.StatusCode < http.StatusBadRequest {
				paymentStatus = "ok"
			}
		}

		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(response{
			Service:   "cart",
			Status:    "ok",
			Payment:   paymentStatus,
			Timestamp: time.Now().UTC().Format(time.RFC3339),
		})
	})

	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})

	log.Println("cart service listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", mux))
}
