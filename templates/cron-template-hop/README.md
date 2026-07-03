# Hop Project Template

This is a minimal Apache Hop project scaffolded by `lds new hop <name>`.

## Structure

```
<project-name>/
├── project-config.json   # Hop project configuration
├── metadata/             # Connections, transform configs
├── pipelines/            # .hpl pipeline files
├── workflows/            # .hwf workflow files
└── datasets/             # CSV datasets for testing
```

## How it works

1. `lds new hop <name>` creates this directory under `HOP_PROJECTS_PATH` (default: `data/hop/projects/`)
2. When `lds up hop` runs, the `hop-register` script registers each project folder in Hop's `hop-config.json` via `hop-conf`
3. Open `http://hop.test` and your project appears in the Project Manager
4. Your pipelines and workflows live on disk — version-control them with git

## Editing

Edit files directly on disk in `HOP_PROJECTS_PATH/<name>/`. Changes are live in Hop
(no container restart needed for file edits — just refresh the Hop UI).
