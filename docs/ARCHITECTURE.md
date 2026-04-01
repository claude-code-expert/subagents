# Architecture / 아키텍처

> Detailed technical documentation for the Squad Agent system.
>
> Squad Agent 시스템의 상세 기술 문서입니다.

---

## Overview / 개요

Squad Agent is a sub-agent system for Claude Code that provides 8 specialized agents, each with a distinct persona, model routing, and tool permissions. Agents chain together via the SubagentStop hook to form automated development pipelines.

Squad Agent는 Claude Code용 서브에이전트 시스템으로, 8종의 전문 에이전트가 고유한 페르소나, 모델 라우팅, 도구 권한을 가집니다. SubagentStop 훅을 통해 파이프라인으로 체이닝됩니다.

---

## Pipeline / 파이프라인

![Squad Pipeline](pipeline-diagram.svg)

### Core Pipeline Flow

```
squad-plan → [implement] → squad-review → squad-qa → squad-gitops
```

### Review-Refactor Loop

```
/squad-review
    │
    ├─ APPROVE ──────────► /squad-qa → /squad-gitops
    │
    └─ REQUEST_CHANGES ──► /squad-refactor
                                │
                                └──► /squad-review (re-verify)
```

`squad-review` is Read-only (find issues), `squad-refactor` is Write (fix them), `squad-qa` has Bash (run tests). Complete separation of concerns.

`squad-review`는 Read-only(찾기만), `squad-refactor`는 Write(수정), `squad-qa`만 Bash(테스트). 관심사 완전 분리.

### Full Map

```
┌─── Core Pipeline ──────────────────────────────────────────────┐
│                                                                │
│  squad-plan → [impl] → squad-review → squad-qa → squad-gitops  │
│    opus                  opus  ◄──┐    sonnet      haiku       │
│    R+W                   R-only   │    R+Bash      R+Bash      │
│                                   │                            │
│                            squad-refactor                      │
│                              opus · R+W                        │
│                                                                │
├─── On-demand ──────────────────────────────────────────────────┤
│  squad-debug (opus)   squad-docs (sonnet)   squad-audit (opus) │
│  R+Bash               R+W                   R-only             │
└────────────────────────────────────────────────────────────────┘
```

---

## Agent Details / 에이전트 상세

### squad-review — Code Review / 코드 리뷰

- `git diff` → Critical/High/Medium/Low classification → `APPROVE` / `REQUEST_CHANGES`
- Bash whitelist: `git diff`, `grep`, `cat` — read-only only. File modification **strictly prohibited**

### squad-plan — Planning / 기획

- User stories (US-001...) + SVG/HTML wireframes (`docs/wireframes/`) + implementation plan
- Analyzes existing code structure before designing

### squad-refactor — Refactoring / 리팩토링

- **PROACTIVELY** triggered on squad-review Medium/Low issues
- **Safe**: Auto-runs `git stash push -m "pre-squad-refactor-checkpoint"` before work
- **Catalog**: Extract, Simplify, Move/Rename, Remove
- **Scope**: Up to module/directory level. STOP at cross-module
- **Workflow**: Assess → Plan (output before modifying) → Execute → Verify → Report
- No testing (squad-qa's domain), no bug fixing

### squad-qa — QA / 테스트

- `timeout 120 npm test` for hang prevention. Build/typecheck/lint validation
- PASS / FAIL / PARTIAL + regression risk assessment. Cannot modify code

### squad-debug — Debugging / 디버깅

- Reproduce → Isolate → Hypothesize → Verify → Root Cause → Solution
- Cannot modify files. Processes verbose logs within sub-agent context

### squad-docs — Documentation / 문서 작성

- README, API docs, architecture docs, JSDoc/TSDoc
- `<!-- auto-generated -->` markers for auto-generated sections

### squad-gitops — Git Automation / Git 자동화

- Conventional Commits messages, PR descriptions, changelogs
- `haiku` for cost optimization. Read-only git commands only

### squad-audit — Security Audit / 보안 감사

- Secrets, OWASP Top 10, `npm audit`, infrastructure security
- Read-only. LOW ~ CRITICAL risk classification

---

## SubagentStop Chaining / 체이닝

| Completed | Suggests |
|-----------|----------|
| squad-plan | → implement, then `/squad-review` |
| squad-review | REQUEST_CHANGES → `/squad-refactor`. APPROVE → `/squad-qa` |
| squad-refactor | → `/squad-review` to verify |
| squad-qa | → `/squad-gitops` commit |

---

## Model Routing / 모델 라우팅

| Agent | Model | Reason |
|-------|-------|--------|
| squad-review | opus | Security/logic = complex reasoning |
| squad-plan | opus | Architecture, edge cases |
| squad-refactor | opus | Code structure understanding + safe transformation |
| squad-qa | sonnet | Test execution + result formatting |
| squad-debug | opus | Root cause analysis |
| squad-docs | sonnet | Code → documentation |
| squad-gitops | haiku | Pattern work, cost-optimized |
| squad-audit | opus | Security — can't afford to miss |

Global override: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## Frontmatter Reference / Frontmatter 레퍼런스

| Field | Required | Default | Description |
|-------|----------|---------|-------------|
| `name` | Yes | — | Agent ID (e.g., `squad-review`) |
| `description` | Yes | — | Auto-delegation trigger. Include `PROACTIVELY` for auto-invoke |
| `tools` | No | (inherit) | Comma-separated. Supports `Task(squad-name)` |
| `model` | No | `inherit` | `haiku` / `sonnet` / `opus` / `inherit` |
| `maxTurns` | No | — | Max turns limit |
| `permissionMode` | No | — | `plan` / `acceptEdits` / `bypassPermissions` |
| `memory` | No | — | `user` / `project` / `local` |
| `background` | No | `false` | Background execution |
| `skills` | No | — | Preloaded skills |
| `mcpServers` | No | — | Agent-specific MCP servers |
| `hooks` | No | — | Agent-specific hooks |

---

## Installed Directory Structure / 설치 디렉토리 구조

```
~/.claude/
├── agents/
│   ├── squad-review.md
│   ├── squad-plan.md
│   ├── squad-refactor.md
│   ├── squad-qa.md
│   ├── squad-debug.md
│   ├── squad-docs.md
│   ├── squad-gitops.md
│   └── squad-audit.md
├── commands/
│   ├── squad.md
│   ├── squad-review.md
│   ├── squad-plan.md
│   ├── squad-refactor.md
│   ├── squad-qa.md
│   ├── squad-debug.md
│   ├── squad-docs.md
│   ├── squad-gitops.md
│   └── squad-audit.md
└── hooks/
    └── subagent-chain.sh
```

---

## Troubleshooting / 디버깅

| Problem | Solution |
|---------|----------|
| Agent not registered | Run `/agents` to verify |
| YAML error | Use `>` block for `description` with `:`, spaces not tabs |
| Infinite execution | Set `maxTurns: 15` |
| Inter-agent calls | Use `tools: Read, Task(squad-review)` |
| Debug mode | `claude --debug "api,hooks"` |

---

## References

- [Claude Code Sub-agents (Official)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
