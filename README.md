# Squad Agent

**[English](README.md)** | **[한국어](README.ko.md)**

**Claude Code sub-agent system with 8 specialized agents for automated development workflows.**

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## Quick Start

### Option 1: One-line Install (curl)

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

---

## How Subagents Work

### What is a Subagent?

A subagent is a specialized AI instance running inside your main Claude Code session with its **own independent context window**. When you ask "review this code" in a normal chat, all analysis fills your main context. With a subagent, heavy analysis happens in a separate window — only the summary returns.

### Internal Mechanism

Subagents are invoked via Claude Code's built-in **Task tool** — not by running `claude -p` in bash.

```
1. User: "/squad-review src/auth/"

2. Main session → Task(subagent_type="squad-review", prompt="...")
   Delegates via Task tool

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

### Why Use Subagents?

1. **Context isolation** — 30k git diff stays in subagent only; main gets 2k summary
2. **Tool scoping** — squad-review is Read-only. Hard constraint at tool level (not prompt)
3. **Parallel execution** — Analyze multiple modules simultaneously
4. **Model routing** — Security gets opus, commit messages get haiku for cost optimization

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
| `squad-review` | Code review | opus | Read-only |
| `squad-plan` | Planning & wireframes | opus | Read+Write |
| `squad-refactor` | Refactoring | opus | Read+Write |
| `squad-qa` | Testing & QA | sonnet | Read+Bash |
| `squad-debug` | Debugging | opus | Read+Bash |
| `squad-docs` | Documentation | sonnet | Read+Write |
| `squad-gitops` | Git automation | haiku | Read+Bash |
| `squad-audit` | Security audit | opus | Read-only |

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

### SubagentStop Hook (Optional)

Enable automatic pipeline chaining by adding to `~/.claude/settings.json`:

```jsonc
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "zsh ~/.claude/hooks/subagent-chain.sh"
          }
        ]
      }
    ]
  }
}
```

### Auto Routing (UserPromptSubmit Hook)

![Squad Router Flow](docs/wireframes/squad-router-flow.svg)

You can invoke subagents with natural language — no slash commands needed. `install.sh` auto-registers the `UserPromptSubmit` hook.

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

80 keywords (42 Korean / 38 English) are mapped across 8 agents. Conflicting keywords (e.g., "PR review" vs "PR write") are automatically resolved to the correct agent.

**Opt-out:**

| Method | Scope | Example |
|--------|-------|---------|
| `--no-route` in prompt | Per-prompt | "review this --no-route" |
| `SQUAD_ROUTER=off` | Global (env) | Disables all routing |
| `/squad-*` slash command | Automatic | Slash commands skip routing |

See [docs/SQUAD-ROUTER-KEYWORDS.md](docs/SQUAD-ROUTER-KEYWORDS.md) for the full keyword reference.

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
