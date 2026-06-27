# cron-template-python

Scheduled job (CronJob-style) in **Python**, via supercronic. No web server.

```bash
lds new cron-python my-job    # scaffold into PYTHON_PROJECTS_PATH
cd <dir> && lds app start
lds app logs
```

Edit `crontab` (schedule) and `job.py` (the task). Add libs via a
`requirements.txt` (uncomment the pip line in the Dockerfile). On `lds-network`.

> See `svc-setting-access-log-retention-python` for a real PyMySQL example.
