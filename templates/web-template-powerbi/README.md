# Power BI Dashboard Template

Scaffolded by `lds new web-powerbi <name>`.

## Structure

```
<project-name>/
├── README.md                 # This file
├── reports/                  # Power BI report definitions (.pbix templates)
├── datasets/                 # Dataset definitions (.yaml)
├── connections/               # Data source connection configs
└── scripts/                  # Deployment/refresh scripts
```

## Usage

1. Design dashboards in Power BI Desktop
2. Store report definitions and dataset configs here
3. Use the scripts for automated deployment/refresh

## Notes

- Power BI reports are binary `.pbix` files (git-track the YAML configs instead)
- Dataset definitions can be version-controlled as YAML
- Connection configs support multiple environments (dev/staging/prod)
