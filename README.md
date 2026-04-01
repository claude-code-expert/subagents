# Squad Agent

**Claude Code sub-agent system with 8 specialized agents for automated development workflows.**

Claude Code 서브에이전트 시스템 — 리뷰, 기획, 리팩토링, QA, 디버깅, 문서, GitOps, 보안 감사를 전문 에이전트에 위임합니다.

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## Quick Start / 빠른 시작

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

[Releases](https://github.com/claude-code-expert/subagents/releases) 페이지에서 최신 `squad-agents-vX.Y.Z.tar.gz`를 다운로드하세요.

```bash
tar xzf squad-agents-v*.tar.gz
bash install.sh
```

### After Install / 설치 후

1. **Restart Claude Code** / Claude Code를 재시작합니다
2. Run `/agents` to verify / `/agents`로 등록을 확인합니다
3. Try `/squad-review` to start / `/squad-review`로 시작해보세요

---

## Agents / 에이전트

| Agent | Role / 역할 | Model | Tools |
|-------|-------------|-------|-------|
| `squad-review` | Code review / 코드 리뷰 | opus | Read, Bash, Glob, Grep |
| `squad-plan` | Planning & wireframes / 기획 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-refactor` | Refactoring / 리팩토링 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-qa` | Testing & QA / 테스트 | sonnet | Read, Bash, Glob, Grep |
| `squad-debug` | Debugging / 디버깅 | opus | Read, Bash, Glob, Grep |
| `squad-docs` | Documentation / 문서 작성 | sonnet | Read, Write, Edit, Glob, Grep |
| `squad-gitops` | Git automation / Git 자동화 | haiku | Read, Bash, Glob, Grep |
| `squad-audit` | Security audit / 보안 감사 | opus | Read, Bash, Glob, Grep |

---

## Pipeline / 파이프라인

The core pipeline chains agents automatically:

코어 파이프라인은 에이전트를 자동으로 체이닝합니다:

```
squad-plan → [implement] → squad-review → squad-qa → squad-gitops
                               │    ▲
                               │    │
                               ▼    │
                          squad-refactor
                           (if changes requested)
```

**On-demand agents** can be invoked anytime:

언제든 호출 가능한 **온디맨드 에이전트**:

- `squad-debug` — Root cause analysis / 근본 원인 분석
- `squad-audit` — Security scanning / 보안 스캐닝
- `squad-docs` — Documentation generation / 문서 생성

### Pipeline Hooks / 파이프라인 훅

`install.sh` automatically registers `SubagentStart` and `SubagentStop` hooks in `~/.claude/settings.json`.

`install.sh`가 `SubagentStart`/`SubagentStop` 훅을 `~/.claude/settings.json`에 자동 등록합니다.

- **SubagentStart** — OS notification + sound when a squad agent starts / 에이전트 시작 시 OS 알림 + 사운드
- **SubagentStop** — OS notification with next pipeline step / 완료 알림 + 다음 단계 안내

> **Note**: Claude Code is a TUI app — `stdout`/`stderr` from SubagentStart/Stop hooks are not displayed in the terminal. The hook uses OS-native notifications instead. See [Notifications](#notifications--알림) for details.
>
> **참고**: Claude Code는 TUI 앱이라 SubagentStart/Stop 훅의 `stdout`/`stderr`가 터미널에 표시되지 않습니다. 대신 OS 네이티브 알림을 사용합니다. 자세한 내용은 [알림](#notifications--알림) 섹션을 참고하세요.

If `jq` is not installed, add manually to `~/.claude/settings.json`:

`jq`가 없는 경우 수동으로 `~/.claude/settings.json`에 추가하세요:

```jsonc
{
  "hooks": {
    "SubagentStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }] }],
    "SubagentStop":  [{ "matcher": "", "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }] }]
  }
}
```

### Subagent Verification / 서브에이전트 검증

All 8 agents are verified to run as independent sub-agents (`isSidechain: true`) with correct model routing:

8개 에이전트 모두 독립 서브에이전트(`isSidechain: true`)로 실행되며, 모델 라우팅이 정확히 적용됨을 검증했습니다:

| Agent | isSidechain | Model Applied |
|-------|-------------|---------------|
| squad-review | `true` | opus |
| squad-plan | `true` | opus |
| squad-refactor | `true` | opus |
| squad-qa | `true` | sonnet |
| squad-debug | `true` | opus |
| squad-docs | `true` | sonnet |
| squad-gitops | `true` | haiku |
| squad-audit | `true` | opus |

Each agent gets a unique `agentId`, separate transcript file, and isolated execution context managed by Claude Code internally.

각 에이전트는 고유한 `agentId`, 별도의 transcript 파일, Claude Code가 관리하는 격리된 실행 컨텍스트를 가집니다.

---

## Notifications / 알림

When a squad agent starts or completes, the hook sends an **OS-native notification** with sound. This works across macOS, Linux, and Windows (WSL).

Squad 에이전트가 시작되거나 완료되면 훅이 **OS 네이티브 알림**과 사운드를 전송합니다. macOS, Linux, Windows(WSL) 모두 지원합니다.

### What you'll see / 알림 내용

| Event / 이벤트 | Notification Title | Notification Body | Sound |
|-------|---------------------|-------------------|-------|
| Agent starts / 시작 | 🚀 Squad: `{agent}` | Status: RUNNING | Pop (macOS) / message.oga (Linux) |
| Agent completes / 완료 | ✅ Squad: `{agent}` | COMPLETED → next step | Glass (macOS) / message.oga (Linux) |

**Example** / 예시: When running `/squad-review`, you'll see: / `/squad-review` 실행 시:

```
🚀 Squad: review          →  ✅ Squad: review
"Status: RUNNING"             "COMPLETED → /squad-refactor or /squad-qa"
```

### Platform Support / 플랫폼 지원

| Platform / 플랫폼 | Notification / 알림 | Sound / 사운드 | Requirement / 요구사항 |
|---------|--------------|-------|-------------|
| **macOS** | `osascript` (Notification Center) | `afplay` (Pop.aiff / Glass.aiff) | Built-in / 기본 내장 |
| **Linux** | `notify-send` (libnotify) | `paplay` or `aplay` | `sudo apt install libnotify-bin` |
| **Windows (WSL)** | PowerShell popup | — | WSL auto-detected / 자동 감지 |
| **Windows (native)** | PowerShell popup | — | Git Bash / MSYS2 |

### Customizing Notifications / 알림 설정 변경

#### Disable notifications / 알림 끄기

Remove the hook entries from `~/.claude/settings.json`:

`~/.claude/settings.json`에서 훅 항목을 제거하세요:

```bash
# Using jq
jq 'del(.hooks.SubagentStart, .hooks.SubagentStop)' ~/.claude/settings.json > tmp.json && mv tmp.json ~/.claude/settings.json
```

Or manually delete the `SubagentStart` and `SubagentStop` keys from the `hooks` object.

또는 `hooks` 객체에서 `SubagentStart`와 `SubagentStop` 키를 수동으로 삭제하세요.

#### Disable sound only / 사운드만 끄기

Edit `~/.claude/hooks/subagent-chain.sh` and comment out the `play_sound` lines:

`~/.claude/hooks/subagent-chain.sh`를 편집하고 `play_sound` 라인을 주석 처리하세요:

```bash
# play_sound "Pop"    # comment out to disable start sound
# play_sound "Glass"  # comment out to disable stop sound
```

#### Change sound / 사운드 변경

**macOS**: Available sounds are in `/System/Library/Sounds/`. Common options:

**macOS**: 사용 가능한 사운드는 `/System/Library/Sounds/`에 있습니다:

```
Basso.aiff    Blow.aiff    Bottle.aiff    Frog.aiff    Funk.aiff
Glass.aiff    Hero.aiff    Morse.aiff     Ping.aiff    Pop.aiff
Purr.aiff     Sosumi.aiff  Submarine.aiff Tink.aiff
```

Edit the `play_sound` function in `~/.claude/hooks/subagent-chain.sh` to change sounds.

`~/.claude/hooks/subagent-chain.sh`의 `play_sound` 함수를 편집하여 사운드를 변경하세요.

**Linux**: Default sounds use freedesktop paths. Point to any `.oga` or `.wav` file:

**Linux**: 기본 freedesktop 경로를 사용합니다. 임의의 `.oga` 또는 `.wav` 파일로 지정 가능:

```bash
paplay /path/to/your/sound.oga
```

#### Notification only for specific agents / 특정 에이전트만 알림 받기

Edit the agent filter in `~/.claude/hooks/subagent-chain.sh`:

`~/.claude/hooks/subagent-chain.sh`에서 에이전트 필터를 편집하세요:

```bash
# Default: all squad agents
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac

# Example: only review and audit
case "$AGENT_NAME" in squad-review|squad-audit) ;; *) exit 0 ;; esac
```

#### Use a different notification tool / 다른 알림 도구 사용

You can replace the `notify()` function in `~/.claude/hooks/subagent-chain.sh`. Examples:

`~/.claude/hooks/subagent-chain.sh`의 `notify()` 함수를 교체할 수 있습니다:

```bash
# Slack webhook
curl -s -X POST "$SLACK_WEBHOOK_URL" -d "{\"text\":\"${title}: ${body}\"}" &

# ntfy.sh (self-hosted or public)
curl -s -d "${body}" "ntfy.sh/my-squad-topic" &

# terminal-notifier (macOS, more options)
terminal-notifier -title "${title}" -message "${body}" -sound default &
```

---

## Commands / 커맨드

| Command | Example / 예시 |
|---------|----------------|
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

## Usage Examples / 사용 예시

### New Feature / 새 기능 개발

```
/squad-plan user profile editing       → Planning / 기획
[implement]                            → Write code / 코드 작성
/squad-review                          → REQUEST_CHANGES
/squad-refactor src/profile/           → Refactor
/squad-review                          → APPROVE
/squad-qa                              → PASS
/squad-audit src/auth/                 → Security check / 보안 점검
/squad-gitops pr                       → Create PR
```

### Production Bug / 프로덕션 버그

```
/squad-debug "TypeError: Cannot read properties of undefined"
[fix]
/squad-qa → /squad-gitops commit
```

### Legacy Cleanup / 레거시 정리

```
/squad-review src/legacy/              → Identify issues
/squad-refactor src/legacy/utils/      → Refactor
/squad-qa                              → Regression test
/squad-docs readme                     → Update docs
```

---

## Model Routing / 모델 라우팅

| Agent | Model | Why / 이유 |
|-------|-------|------------|
| squad-review | opus | Security & logic require deep reasoning / 보안·로직은 깊은 추론 필요 |
| squad-plan | opus | Architecture & edge case design / 설계와 엣지케이스 |
| squad-refactor | opus | Safe structural transformation / 안전한 구조 변환 |
| squad-qa | sonnet | Test execution & result formatting / 테스트 실행·결과 정리 |
| squad-debug | opus | Root cause analysis / 근본 원인 분석 |
| squad-docs | sonnet | Code-to-documentation / 코드→문서화 |
| squad-gitops | haiku | Pattern work, cost-optimized / 패턴 작업, 비용 최적화 |
| squad-audit | opus | Security — can't afford to miss / 보안은 놓치면 안 됨 |

Override globally: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## Project Override / 프로젝트별 오버라이드

Place `.claude/agents/squad-review.md` in your project to override the global version:

프로젝트에 `.claude/agents/squad-review.md`를 두면 전역 버전보다 우선합니다:

```markdown
---
name: squad-review
description: >
  Expert code review for MyProject.
tools: Read, Bash, Glob, Grep
model: opus
---

## MyProject Rules
- TypeScript `any` PROHIBITED
- All API responses must use Result type
...
```

---

## Uninstall / 제거

```bash
bash install.sh --uninstall
```

This removes only Squad Agent files from `~/.claude/`. Backup files (`.bak`) are preserved. Hook entries in `settings.json` must be removed manually.

Squad Agent 파일만 `~/.claude/`에서 제거합니다. 백업 파일(`.bak`)은 유지됩니다. `settings.json`의 훅 항목은 수동으로 제거해야 합니다.

---

## Architecture / 아키텍처

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

상세 아키텍처 문서는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참고하세요.

---

## Contributing / 기여

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding new agents or improving existing ones.

새 에이전트 추가나 개선 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

---

## License

[Apache License 2.0](LICENSE)

---

## References

- [Claude Code Sub-agents (Official)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
