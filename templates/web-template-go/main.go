package main

import (
	"html/template"
	"log"
	"net/http"
	"os"
)

// Server-rendered web counterpart of svc-template-go (which returns JSON).
var page = template.Must(template.New("index").Parse(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>web-template-go</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:40rem;margin:4rem auto;padding:0 1rem}</style>
</head><body>
  <h1>web-template-go</h1>
  <p>Hello from a Go server-rendered page (html/template).</p>
  <p>Host: <code>{{.Host}}</code></p>
</body></html>`)

func main() {
	mux := http.NewServeMux()

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok"))
	})

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		host, _ := os.Hostname()
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		page.Execute(w, map[string]string{"Host": host})
	})

	// Backing services on lds-network: mysql:3306 postgres:5432 redis:6379 ...
	addr := ":8080"
	log.Printf("web-template-go listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
