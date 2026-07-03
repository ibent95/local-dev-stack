# Pentaho Data Integration (Kettle) Project Template

Scaffolded by `lds new pdi <name>` or `lds new cron-pdi <name>`.

## Structure

```
<project-name>/
├── README.md                 # This file
├── connections/              # Database connection definitions (.kdb files)
├── transformations/          # .ktr transformation files
├── jobs/                     # .kjb job files
└── resources/                # Shared resources (CSV, XML, etc.)
```

## Usage

1. Open Spoon (PDI GUI) or use the PDI CLI
2. Import transformations and jobs from this directory
3. Schedule jobs via cron or the LDS cron infrastructure

## Notes

- PDI stores transformations (`.ktr`) and jobs (`.kjb`) as XML files
- Connections are stored separately for portability
- This template is designed for standalone ETL jobs that run on a schedule
