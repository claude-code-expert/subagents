# Changelog

All notable changes to this project will be documented in this file.

## [1.1.3] - 2026-04-01

### Added

- **SubagentStart/Stop banners**: Console banner display when squad agents start/stop
- **SHA256 checksum verification**: Remote install now verifies archive integrity
- **Auto hook registration**: `install.sh` automatically registers SubagentStart and SubagentStop hooks via `jq`
- **Boundaries section**: All 8 agents now have explicit Will/Will Not boundaries

### Fixed

- **subagent-chain.sh**: Fixed shebang mismatch (`bash` → `zsh`) to match execution shell
- **subagent-chain.sh**: Fixed field name (`agent_name` → `agent_type`) to match actual schema
- **squad-docs**: Workflow now uses Glob tool instead of Bash `find` command
- **install.sh**: Version read from VERSION file to eliminate dual management

### Improved

- Standardized Bash section names (`Allowed Commands` / `NEVER Run`) across all agents
- Standardized tool ordering (`Read, Bash, Glob, Grep`) across all agents
- Semver tag validation for remote install (`^v[0-9]+.[0-9]+.[0-9]+$`)
- Release workflow generates `.sha256` checksum file alongside archive
- README updated with accurate tool lists and auto-hook documentation
- Uninstall docs note that settings.json hooks require manual removal

## [1.1.0] - 2026-04-01

### Fixed

- **squad-docs**: Added safety rules — NEVER modify source code, Boundaries (Will/Will Not)
- **squad-plan**: Added safety rules, Boundaries, Bash Whitelist/BLACKLIST (had Write+Bash with zero restrictions)

### Improved

- All 8 agents now include `Pipeline:` line in description for workflow context
- Standardized tool ordering across all agents (`Read, Bash, Glob, Grep` / `Read, Write, Edit, Bash, Glob, Grep`)
- Extracted inline bash restrictions into dedicated `Allowed Commands` / `NEVER Run` sections (squad-audit, squad-review, squad-gitops)
- Replaced emoji (✅/❌) with text (PASS/FAIL) in squad-qa output format for consistency
- Enhanced squad-plan command with output description
- Enhanced squad-debug command with input format and output description

## [1.0.0] - 2026-04-01

### Added

- 8 specialized agents: review, plan, refactor, qa, debug, docs, gitops, audit
- 9 slash commands including universal `/squad` command
- SubagentStop pipeline chaining hook
- One-line install script (local + remote + uninstall)
- GitHub Actions release automation
- Bilingual README (EN + KO)
- Architecture documentation and pipeline diagram
