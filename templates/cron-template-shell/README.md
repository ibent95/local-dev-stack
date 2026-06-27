# cron-template-shell

Scheduled job (CronJob-style) in **POSIX shell**, via supercronic. No web server.

```bash
lds new cron-shell my-job     # scaffold into JOBS_PROJECTS_PATH
cd <dir> && lds app start     # run on schedule
lds app logs                  # watch each run
```

Edit `crontab` (schedule) and `job.sh` (the task). On `lds-network`, so it
reaches `mysql`, `postgres`, `mongo`, `redis`, `kafka-broker` by name.
