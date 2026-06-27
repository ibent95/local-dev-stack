package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"service":  "go",
			"message":  "Hello from Go (net/http)",
			"hostname": host,
		})
	})

	// Backing services are reachable on the lds-network network by name, e.g.:
	//   mysql:3306  postgres:5432  redis:6379  kafka-broker:9092
	addr := ":8080"
	log.Printf("go listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
