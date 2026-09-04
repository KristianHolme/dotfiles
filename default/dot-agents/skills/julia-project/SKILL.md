---
name: julia-project
description: >-
  Julia project and package workflow: Project.toml/Manifest discipline, Pkg
  usage, and JLD2 struct migration for saved scientific data. Use when editing
  environments, adding dependencies, changing Project.toml, or loading old JLD2
  files after type changes.
---

# Julia project

## Project.toml / Manifest.toml

- Do **not** edit `Project.toml`, `Manifest.toml`, or similar env files without explicit user approval.
- Prefer the Julia MCP / Pkg.jl API when available.
- If Pkg changes are needed and you cannot use those APIs, ask the user to run the Pkg commands or approve the edit.

## Backward compatibility when changing structs

When structs (or modules) change, old JLD2 files can fail to load. Use **JLD2 typemap and `rconvert`** to upgrade stored data.

1. **Define conversion** — `JLD2.rconvert(::Type{NewType}, nt::NamedTuple)` building the new struct from stored fields. Use `get(nt, :field, default)` and `haskey` for old vs new layouts.

2. **Register old type paths** — typemap such as  
   `Dict("OldModule.OldTypeName" => JLD2.Upgrade(NewType), ...)`.

3. **Load with typemap** — `load(path; typemap = typemap)`. Re-saving persists new types.

For conditional upgrades, use a typemap function  
`(f, typepath, params) -> JLD2.Upgrade(SomeType)` or `JLD2.default_typemap(...)`.  
`rconvert` / `Upgrade` / `default_typemap` may be non-public APIs used for migration.
