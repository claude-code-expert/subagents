# Squad Agent

**[English](README.en.md)** | **[한국어](README.md)**

**Claude Code sub-agent system with 8 specialized agents for automated development workflows.**

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## Quick Start

### Option 1: One-line Install (curl) — Recommended

```bash
curl -sL https://raw.githubusercontent.com/claude-code-expert/subagents/main/install.sh | bash
```

### Option 2: Clone & Install

```bash
git clone https://github.com/claude-code-expert/subagents.git
cd subagents
bash install.sh
```

### Option 3: Download Release

Download the latest `squad-agents-vX.Y.Z.tar.gz` from the [Releases](https://github.com/claude-code-expert/subagents/releases) page.

```bash
tar xzf squad-agents-v*.tar.gz
bash install.sh
```

### After Install

1. **Restart Claude Code**
2. Run `/agents` to verify registration
3. Try `/squad-review` to start

The installer auto-registers all 3 hooks (SubagentStart, SubagentStop, UserPromptSubmit) in `~/.claude/settings.json`.

---

## How Subagents Work

### What is a Subagent?

A subagent is a specialized AI instance running inside your main Claude Code session with its **own independent context window**. When you ask "review this code" in a normal chat, all analysis fills your main context. With a subagent, heavy analysis happens in a separate window — only the summary returns.

### Internal Mechanism

Subagents are invoked via Claude Code's built-in **Agent tool** — not by running `claude -p` in bash.

```
1. User: "/squad-review src/auth/"

2. Main session → Agent(subagent_type="squad-review", prompt="...")
   Delegates via Agent tool

3. New context window created:
   - System prompt from squad-review.md loaded
   - Only tools listed in frontmatter available
   - Model specified in frontmatter used

4. Subagent works in its own context:
   - git diff, file reads, analysis — all stay in subagent context
   - Main session context does NOT grow

5. Result returned:
   - Only the final message returns to main session
   - Subagent context is discarded
```

### Version

**v1.3.2** (current) — [Full changelog](CHANGELOG.md)

| Version | Key Changes |
|---------|-------------|
| v1.3.2 | 145 automated tests, pre-commit hook, router delegation enforcement, `run-all.sh` |
| v1.3.1 | README restructure (KO/EN split), CI shellcheck fix, hook mechanism docs |
| v1.3.0 | Squad Router hook (80 keywords, 3-phase matching, context injection) |
| v1.2.1 | Cross-platform notifications (macOS/Linux/WSL), subagent verification |
| v1.1.3 | SubagentStart/Stop banners, SHA256 checksum, auto hook registration |
| v1.1.0 | Agent safety rules, pipeline context, tool ordering standardization |
| v1.0.0 | 8 agents, 9 commands, SubagentStop hook, install script |

<!--
### Honest Token Economics

> **"Subagents save tokens" is a common misconception. They actually use MORE.**

The value of subagents is not token savings — it's **main context quality preservation**.

#### Example: Code review on 20 changed files

**Inline (no subagent):**

```
Main context: 24k (conversation) + 30k (git diff) + 16k (file reads) + 15k (analysis) = 85k
Remaining for coding: 115k / 200k
Total tokens consumed: ~85k
```

**With squad-review subagent:**

```
Main context:     24k (conversation) + 2k (returned summary) = 26k
Subagent context: 4k (system) + 30k (diff) + 16k (reads) + 15k (analysis) + 4k (overhead) = 69k (discarded)
Remaining for coding: 174k / 200k
Total tokens consumed: ~95k (MORE than inline)
```

| Metric | Inline | Subagent |
|--------|--------|----------|
| Main context used | 85k | 26k |
| Total tokens consumed | 85k | **95k (+12%)** |
| Remaining workspace | 115k | **174k (+51%)** |
| Session quality over time | Degrades (context rot) | **Maintained** |

#### Parallel execution cost

Per Anthropic docs, multi-agent workflows use roughly **4-7x more tokens** than single-agent sessions. Real-world reports: 5 parallel subagents on Pro plan exhausted limits in 15 minutes (vs 30 minutes sequential).

#### When subagents are worth it

| Worth it | Not worth it |
|----------|-------------|
| Verbose output (large diffs, logs) | Simple single-file lookups |
| Long sessions (context rot prevention) | Short sessions |
| Read-heavy research & exploration | Holistic codebase reasoning |
| Parallel independent analyses | Sequential dependent steps |
| Enforcing tool restrictions (Read-only) | Tasks needing all tools |

> **Bottom line:** Subagents are a **context hygiene tool**, not a token savings tool. They keep your main session clean so quality doesn't degrade. You pay more tokens total, but you get a better workspace.
-->

### Why Use Subagents?

1. **Context isolation & main context pollution prevention** — 30k git diff stays in subagent only; main gets 2k summary. As main context grows, token consumption scales proportionally per turn — subagents keep it lean
2. **Tool scoping** — squad-review is Read-only. Hard constraint at tool level (not prompt)
3. **Parallel execution** — Analyze multiple modules simultaneously
4. **Model routing** — Security gets opus, commit messages get haiku for cost optimization

> **Why subagents save tokens long-term:**
>
> 1. Per-operation, subagents cost more (85k vs 95k)
> 2. But if 85k accumulates in main context, that 85k is re-sent as input tokens **every turn**
> 3. With subagents, main stays at 26k → saves 59k input tokens per subsequent turn
> 4. After just 10 turns: `59k × 10 = 590k` token savings — far exceeding the initial 10k overhead
>
> The longer your session, the greater the compounding value of subagents.

### Agent Definition Format

```markdown
---
name: squad-review                    # Agent ID
description: >                        # Auto-delegation trigger
  Use PROACTIVELY after code changes.
tools: Read, Grep, Glob, Bash         # Allowed tools (hard constraint)
model: opus                           # Model
maxTurns: 15                          # Safety limit
---
You are a senior staff engineer...    # System prompt
```

---

## Agents

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| `squad-review` | Code review | opus | Read, Bash, Glob, Grep |
| `squad-plan` | Planning & wireframes | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-refactor` | Refactoring | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-qa` | Testing & QA | sonnet | Read, Bash, Glob, Grep |
| `squad-debug` | Debugging | opus | Read, Bash, Glob, Grep |
| `squad-docs` | Documentation | sonnet | Read, Write, Edit, Glob, Grep |
| `squad-gitops` | Git automation | haiku | Read, Bash, Glob, Grep |
| `squad-audit` | Security audit | opus | Read, Bash, Glob, Grep |

---

## Pipeline

The core pipeline chains agents automatically:

```
squad-plan → [implement] → squad-review → squad-qa → squad-gitops
                               │    ▲
                               │    │
                               ▼    │
                          squad-refactor
                           (if changes requested)
```

**On-demand agents** can be invoked anytime:

- `squad-debug` — Root cause analysis
- `squad-audit` — Security scanning
- `squad-docs` — Documentation generation

---

## Hooks

Three hooks power the automation layer. All are auto-registered by `install.sh`.

### 1. Squad Router (UserPromptSubmit)

![Squad Router Flow](docs/wireframes/squad-router-flow.svg)

Natural language auto-routing — no slash commands needed. Detects keywords in user prompts and injects subagent delegation context.

#### How It Works

Claude Code's `UserPromptSubmit` hook fires every time the user submits a prompt. Squad Router leverages this mechanism:

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. User submits a prompt                                        │
│    "run a security check on this code"                          │
│                                                                 │
│ 2. Claude Code executes the hook (before prompt reaches Claude) │
│    stdin → {"prompt": "run a security check on this code"}      │
│                                                                 │
│ 3. squad-router.sh matches keywords                             │
│    "security" detected → AGENT="squad-audit"                    │
│                                                                 │
│ 4. Outputs JSON to stdout (context injection)                   │
│    {"hookSpecificOutput": {                                      │
│      "hookEventName": "UserPromptSubmit",                        │
│      "additionalContext": "[Squad Router] Use the squad-audit..." │
│    }}                                                            │
│                                                                 │
│ 5. Claude sees injected context and delegates to subagent       │
│    → Agent(subagent_type="squad-audit", prompt="...")            │
└─────────────────────────────────────────────────────────────────┘
```

The key is `hookSpecificOutput.additionalContext`. Text output via this field is injected as a system-reminder when Claude processes the prompt, naturally guiding Claude to invoke the appropriate subagent. The original prompt is not modified.

```
"review this code"     → squad-review
"debug this error"     → squad-debug
"security check"       → squad-audit
"run the tests"        → squad-qa
"plan the feature"     → squad-plan
"refactor this"        → squad-refactor
"document this API"    → squad-docs
"write commit message" → squad-gitops
```

**80 keywords** (42 Korean / 38 English) across 8 agents with 3-phase matching:

1. **Skip** — slash commands, `--no-route`, `SQUAD_ROUTER=off`
2. **Conflict resolution** — multi-word patterns (e.g., "PR review" → review, "PR write" → gitops)
3. **General keywords** — priority-ordered single-word matching

**Opt-out:**

| Method | Scope | Example |
|--------|-------|---------|
| `--no-route` in prompt | Per-prompt | "review this --no-route" |
| `SQUAD_ROUTER=off` | Global (env) | Disables all routing |
| `/squad-*` slash command | Automatic | Slash commands skip routing |

See [docs/SQUAD-ROUTER-KEYWORDS.md](docs/SQUAD-ROUTER-KEYWORDS.md) for the full keyword reference.

### 2. Pipeline Chaining (SubagentStart / SubagentStop)

The `subagent-chain.sh` hook handles both start and stop events:

- **SubagentStart** — OS notification: "Squad: {agent} RUNNING"
- **SubagentStop** — OS notification: "Squad: {agent} COMPLETED" + next-step guidance

Next-step guidance per agent:

| Agent | On Complete |
|-------|-------------|
| squad-plan | → implement, then /squad-review |
| squad-review | → /squad-refactor or /squad-qa |
| squad-refactor | → /squad-review to verify |
| squad-qa | → /squad-gitops commit |
| squad-debug | → implement the fix |
| squad-docs | Documentation updated. |
| squad-gitops | Git artifacts generated. |
| squad-audit | Address findings before deploy. |

### 3. Notifications (Cross-platform)

Native OS notifications fire on every subagent start/stop:

| Platform | Method | Sound |
|----------|--------|-------|
| macOS | `osascript` (Notification Center) | `afplay` (Pop/Glass) |
| Linux | `notify-send` | `paplay` / `aplay` |
| Windows/WSL | PowerShell popup | — |

**Disable notifications:**

```bash
# Remove SubagentStart/SubagentStop hooks from ~/.claude/settings.json
# Or comment out notify() calls in ~/.claude/hooks/subagent-chain.sh
```

### Hook Registration (settings.json)

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/squad-router.sh" }]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }]
      }
    ]
  }
}
```

---

## Commands

| Command | Example |
|---------|---------|
| `/squad-review` | `/squad-review src/auth/` |
| `/squad-plan` | `/squad-plan payment system` |
| `/squad-refactor` | `/squad-refactor src/utils/` |
| `/squad-qa` | `/squad-qa` |
| `/squad-debug` | `/squad-debug TypeError: Cannot read...` |
| `/squad-docs` | `/squad-docs readme` |
| `/squad-gitops` | `/squad-gitops pr` |
| `/squad-audit` | `/squad-audit` |
| `/squad` | `/squad review src/auth/` (universal) |

---

## Usage Examples

### New Feature

```
/squad-plan user profile editing       → Planning
[implement]                            → Write code
/squad-review                          → REQUEST_CHANGES
/squad-refactor src/profile/           → Refactor
/squad-review                          → APPROVE
/squad-qa                              → PASS
/squad-audit src/auth/                 → Security check
/squad-gitops pr                       → Create PR
```

### Production Bug

```
/squad-debug "TypeError: Cannot read properties of undefined"
[fix]
/squad-qa → /squad-gitops commit
```

### Legacy Cleanup

```
/squad-review src/legacy/              → Identify issues
/squad-refactor src/legacy/utils/      → Refactor
/squad-qa                              → Regression test
/squad-docs readme                     → Update docs
```

---

## Model Routing

| Agent | Model | Why |
|-------|-------|-----|
| squad-review | opus | Security & logic require deep reasoning |
| squad-plan | opus | Architecture & edge case design |
| squad-refactor | opus | Safe structural transformation |
| squad-qa | sonnet | Test execution & result formatting |
| squad-debug | opus | Root cause analysis |
| squad-docs | sonnet | Code-to-documentation |
| squad-gitops | haiku | Pattern work, cost-optimized |
| squad-audit | opus | Security — can't afford to miss |

Override globally: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## Project Override

Place `.claude/agents/squad-review.md` in your project to override the global version:

```markdown
---
name: squad-review
description: >
  Expert code review for MyProject.
tools: Read, Grep, Glob, Bash
model: opus
---

## MyProject Rules
- TypeScript `any` PROHIBITED
- All API responses must use Result type
...
```

---

## Uninstall

```bash
bash install.sh --uninstall
```

This removes only Squad Agent files from `~/.claude/`. Backup files (`.bak`) are preserved.

> Note: Hook entries in `~/.claude/settings.json` require manual removal.

---

## Architecture

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding new agents or improving existing ones.

---

## License

[Apache License 2.0](LICENSE)

---

## References

- [Claude Code Sub-agents (Official)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
