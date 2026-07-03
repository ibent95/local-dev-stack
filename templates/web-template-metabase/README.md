# Metabase Dashboard Template

Scaffolded by `lds new web-metabase <name>`.

## Structure

```
<project-name>/
├── README.md                 # This file
├── questions/                # Saved question definitions (.json)
├── dashboards/               # Dashboard definitions (.json)
├── collections/              # Collection hierarchy (.json)
├── connections/              # Database connection configs (.yaml)
└── scripts/                  # Import/export automation scripts
```

## Usage

1. Design dashboards in the Metabase UI
2. Export questions/dashboards from Metabase Admin → Serialization
3. Store exported JSON files in the appropriate subdirectories
4. Version-control with git for team collaboration

## Notes

- Metabase stores questions, dashboards, and collections as JSON when serialized
- Use Metabase's built-in serialization (`metabase export`) for full fidelity
- Connection configs are YAML for easy environment switching
- Metabase can be added to the LDS stack as a service profile if needed
