# cron-template-go

Scheduled job (CronJob-style) in **Go**, via supercronic. No web server.
Compiled: the image builds `job.go` into a binary, then supercronic runs it on
schedule (no recompile per run).

```bash
lds new cron-go my-job        # scaffold into GO_PROJECTS_PATH
cd <dir> && lds app start
lds app logs
```

Edit `crontab` (schedule) and `job.go` (the task); add modules to `go.mod`.
On `lds-network`. Rebuild on change: `lds app restart`.
