# cron-template-php

Scheduled job (CronJob-style) in **PHP (CLI)**, via supercronic. No web server.

```bash
lds new cron-php my-job       # scaffold into PHP_PROJECTS_PATH
cd <dir> && lds app start
lds app logs
```

Edit `crontab` (schedule) and `job.php` (the task). On `lds-network`.
