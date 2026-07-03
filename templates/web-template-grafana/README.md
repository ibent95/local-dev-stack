# Grafana Dashboard Template

Scaffolded by `lds new web-grafana <name>`.

## Structure

```
<project-name>/
├── README.md                 # This file
├── dashboards/               # Dashboard JSON definitions
├── datasources/              # Data source configs (.yaml)
├── alerting/                 # Alert rules (.json)
├── provisioning/             # Provisioning configs (.yaml)
└── scripts/                  # Import/export automation scripts
```

## Usage

1. Design dashboards in the Grafana UI at `grafana.test`
2. Export dashboards as JSON from the dashboard settings
3. Store JSON files in `dashboards/` for git version control
4. Use provisioning configs for declarative data source setup

## Notes

- Grafana dashboards export as self-contained JSON (panels, queries, variables)
- Data sources can be provisioned declaratively via YAML in `datasources/`
- Use the Grafana API (`/api/dashboards/import`) for scripted imports
- Grafana can be added to the LDS stack as a service profile if needed
