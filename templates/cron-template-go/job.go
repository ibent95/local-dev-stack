// Your scheduled task. Output goes to stdout (lds app logs). Keep it idempotent.
package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	host, _ := os.Hostname()
	fmt.Printf("[%s] cron-template-go: ran on %s\n", time.Now().Format(time.RFC3339), host)

	// Backing services are reachable by name on lds-network, e.g.:
	//   http.Get("http://my-svc:8080/health")
	//   sql.Open("mysql", "root:root@tcp(mysql:3306)/app")  // add the driver to go.mod
}
