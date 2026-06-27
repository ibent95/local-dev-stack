# cron-template-node

Scheduled job (CronJob-style) in **Node.js**, via supercronic. No web server.

```bash
lds new cron-node my-job      # scaffold into NODE_PROJECTS_PATH
cd <dir> && lds app start
lds app logs
```

Edit `crontab` (schedule) and `job.js` (the task). Add deps via `package.json`
(uncomment the npm line in the Dockerfile). On `lds-network`.
