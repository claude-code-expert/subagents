# Contributing / 기여 가이드

Thank you for contributing to Squad Agent!

Squad Agent에 기여해 주셔서 감사합니다!

## Adding a New Agent / 새 에이전트 추가

Each agent requires **two files**:

새 에이전트를 추가하려면 **두 개의 파일**이 필요합니다:

### 1. Agent definition: `agents/squad-{name}.md`

```markdown
---
name: squad-{name}
description: >
  What this agent does. Include trigger keywords.
  Use PROACTIVELY if it should auto-invoke.
tools: Read, Grep, Glob
model: opus
maxTurns: 15
---

System prompt for the agent goes here.
Describe its role, rules, process, and output format.
```

### 2. Command definition: `commands/squad-{name}.md`

```markdown
---
description: "Short description. Usage: /squad-{name} [args]"
allowed-tools: Agent
---
Invoke the squad-{name} subagent.
$ARGUMENTS
```

### 3. Register in `commands/squad.md`

Add your agent to the available agents list in `commands/squad.md`.

`commands/squad.md`의 에이전트 목록에 추가하세요.

### 4. Update `install.sh`

Add the new agent name to the `SQUAD_AGENTS` array in `install.sh`.

`install.sh`의 `SQUAD_AGENTS` 배열에 새 에이전트 이름을 추가하세요.

---

## Frontmatter Reference / Frontmatter 레퍼런스

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Agent ID (e.g., `squad-review`) |
| `description` | Yes | — | Auto-delegation trigger. Include `PROACTIVELY` for auto-invoke |
| `tools` | No | (inherit) | Comma-separated. Supports `Task(squad-name)` |
| `model` | No | `inherit` | `haiku` / `sonnet` / `opus` / `inherit` |
| `maxTurns` | No | — | Max turns limit |

---

## Naming Convention / 네이밍 규칙

- Prefix: `squad-` + descriptive function name
- Examples: `squad-review`, `squad-plan`, `squad-audit`

---

## Pull Request Guidelines / PR 가이드라인

1. One agent per PR / PR당 하나의 에이전트
2. Include both `agents/` and `commands/` files / 두 파일 모두 포함
3. Test with `bash install.sh` locally / 로컬에서 설치 테스트
4. Update README agent table if adding new agents / 새 에이전트 추가 시 README 테이블 갱신
5. Use [Conventional Commits](https://www.conventionalcommits.org/) / Conventional Commits 사용

---

## Code Style

- Shell scripts: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Agent prompts: Clear, concise, with structured output formats
- Use `set -euo pipefail` in all shell scripts
