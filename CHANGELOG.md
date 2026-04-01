# Changelog

All notable changes to this project will be documented in this file.

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
