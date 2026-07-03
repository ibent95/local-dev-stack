# Apache Superset Dashboard Template

Scaffolded by `lds new web-superset <name>`.

## Structure

```
<project-name>/
├── README.md                 # This file
├── dashboards/               # Dashboard YAML definitions
├── charts/                   # Chart YAML definitions
├── datasets/                 # Dataset YAML definitions
├── databases/                # Database connection YAML definitions
└── import.sh                 # Script to import into Superset
```

## Usage

1. Create dashboards in the Superset UI at `superset.test`
2. Export them with `lds superset export`
3. Or manually create YAML files following the Superset export format
4. Import with `lds superset import` or `./import.sh`

## Notes

- Superset dashboards are stored as YAML files for git version control
- The export format includes dependencies (charts → datasets → databases)
- Use `lds superset export` to save your work from the UI to disk
