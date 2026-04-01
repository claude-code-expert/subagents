# Squad Agent

**[English](README.md)** | **[한국어](README.ko.md)**

**Claude Code 서브에이전트 시스템 — 리뷰, 기획, 리팩토링, QA, 디버깅, 문서, GitOps, 보안 감사를 전문 에이전트에 위임합니다.**

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## 빠른 시작

### 방법 1: 원라인 설치 (curl) — 권장

```bash
curl -sL https://raw.githubusercontent.com/claude-code-expert/subagents/main/install.sh | bash
```

### 방법 2: 클론 후 설치

```bash
git clone https://github.com/claude-code-expert/subagents.git
cd subagents
bash install.sh
```

### 방법 3: 릴리스 다운로드

[Releases](https://github.com/claude-code-expert/subagents/releases) 페이지에서 최신 `squad-agents-vX.Y.Z.tar.gz`를 다운로드하세요.

```bash
tar xzf squad-agents-v*.tar.gz
bash install.sh
```

### 설치 후

1. **Claude Code를 재시작합니다**
2. `/agents`로 등록을 확인합니다
3. `/squad-review`로 시작해보세요

---

## 에이전트

| 에이전트 | 역할 | 모델 | 도구 |
|---------|------|------|------|
| `squad-review` | 코드 리뷰 | opus | Read, Bash, Glob, Grep |
| `squad-plan` | 기획 & 와이어프레임 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-refactor` | 리팩토링 | opus | Read, Write, Edit, Bash, Glob, Grep |
| `squad-qa` | 테스트 & QA | sonnet | Read, Bash, Glob, Grep |
| `squad-debug` | 디버깅 | opus | Read, Bash, Glob, Grep |
| `squad-docs` | 문서 작성 | sonnet | Read, Write, Edit, Glob, Grep |
| `squad-gitops` | Git 자동화 | haiku | Read, Bash, Glob, Grep |
| `squad-audit` | 보안 감사 | opus | Read, Bash, Glob, Grep |

---

## 파이프라인

코어 파이프라인은 에이전트를 자동으로 체이닝합니다:

```
squad-plan → [구현] → squad-review → squad-qa → squad-gitops
                           │    ▲
                           │    │
                           ▼    │
                      squad-refactor
                       (변경 요청 시)
```

언제든 호출 가능한 **온디맨드 에이전트**:

- `squad-debug` — 근본 원인 분석
- `squad-audit` — 보안 스캐닝
- `squad-docs` — 문서 생성

### 파이프라인 훅

`install.sh`가 `SubagentStart`/`SubagentStop` 훅을 `~/.claude/settings.json`에 자동 등록합니다.

- **SubagentStart** — 에이전트 시작 시 OS 알림 + 사운드
- **SubagentStop** — 완료 알림 + 다음 단계 안내

> **참고**: Claude Code는 TUI 앱이라 SubagentStart/Stop 훅의 `stdout`/`stderr`가 터미널에 표시되지 않습니다. 대신 OS 네이티브 알림을 사용합니다. 자세한 내용은 [알림](#알림) 섹션을 참고하세요.

`jq`가 없는 경우 수동으로 `~/.claude/settings.json`에 추가하세요:

```jsonc
{
  "hooks": {
    "SubagentStart": [{ "matcher": "", "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }] }],
    "SubagentStop":  [{ "matcher": "", "hooks": [{ "type": "command", "command": "zsh ~/.claude/hooks/subagent-chain.sh" }] }]
  }
}
```

### 서브에이전트 검증

8개 에이전트 모두 독립 서브에이전트(`isSidechain: true`)로 실행되며, 모델 라우팅이 정확히 적용됨을 검증했습니다:

| 에이전트 | isSidechain | 적용 모델 |
|---------|-------------|----------|
| squad-review | `true` | opus |
| squad-plan | `true` | opus |
| squad-refactor | `true` | opus |
| squad-qa | `true` | sonnet |
| squad-debug | `true` | opus |
| squad-docs | `true` | sonnet |
| squad-gitops | `true` | haiku |
| squad-audit | `true` | opus |

각 에이전트는 고유한 `agentId`, 별도의 transcript 파일, Claude Code가 관리하는 격리된 실행 컨텍스트를 가집니다.

---

## 알림

Squad 에이전트가 시작되거나 완료되면 훅이 **OS 네이티브 알림**과 사운드를 전송합니다. macOS, Linux, Windows(WSL) 모두 지원합니다.

### 알림 내용

| 이벤트 | 알림 제목 | 알림 본문 | 사운드 |
|--------|----------|----------|--------|
| 에이전트 시작 | 🚀 Squad: `{agent}` | Status: RUNNING | Pop (macOS) / message.oga (Linux) |
| 에이전트 완료 | ✅ Squad: `{agent}` | COMPLETED → 다음 단계 | Glass (macOS) / message.oga (Linux) |

**예시**: `/squad-review` 실행 시:

```
🚀 Squad: review          →  ✅ Squad: review
"Status: RUNNING"             "COMPLETED → /squad-refactor or /squad-qa"
```

### 플랫폼 지원

| 플랫폼 | 알림 | 사운드 | 요구사항 |
|--------|------|--------|---------|
| **macOS** | `osascript` (알림 센터) | `afplay` (Pop.aiff / Glass.aiff) | 기본 내장 |
| **Linux** | `notify-send` (libnotify) | `paplay` 또는 `aplay` | `sudo apt install libnotify-bin` |
| **Windows (WSL)** | PowerShell 팝업 | — | 자동 감지 |
| **Windows (네이티브)** | PowerShell 팝업 | — | Git Bash / MSYS2 |

### 알림 설정 변경

#### 알림 끄기

`~/.claude/settings.json`에서 훅 항목을 제거하세요:

```bash
# jq 사용
jq 'del(.hooks.SubagentStart, .hooks.SubagentStop)' ~/.claude/settings.json > tmp.json && mv tmp.json ~/.claude/settings.json
```

또는 `hooks` 객체에서 `SubagentStart`와 `SubagentStop` 키를 수동으로 삭제하세요.

#### 사운드만 끄기

`~/.claude/hooks/subagent-chain.sh`를 편집하고 `play_sound` 라인을 주석 처리하세요:

```bash
# play_sound "Pop"    # 시작 사운드 비활성화
# play_sound "Glass"  # 종료 사운드 비활성화
```

#### 사운드 변경

**macOS**: 사용 가능한 사운드는 `/System/Library/Sounds/`에 있습니다:

```
Basso.aiff    Blow.aiff    Bottle.aiff    Frog.aiff    Funk.aiff
Glass.aiff    Hero.aiff    Morse.aiff     Ping.aiff    Pop.aiff
Purr.aiff     Sosumi.aiff  Submarine.aiff Tink.aiff
```

`~/.claude/hooks/subagent-chain.sh`의 `play_sound` 함수를 편집하여 사운드를 변경하세요.

**Linux**: 기본 freedesktop 경로를 사용합니다. 임의의 `.oga` 또는 `.wav` 파일로 지정 가능:

```bash
paplay /path/to/your/sound.oga
```

#### 특정 에이전트만 알림 받기

`~/.claude/hooks/subagent-chain.sh`에서 에이전트 필터를 편집하세요:

```bash
# 기본값: 모든 squad 에이전트
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac

# 예시: review와 audit만
case "$AGENT_NAME" in squad-review|squad-audit) ;; *) exit 0 ;; esac
```

#### 다른 알림 도구 사용

`~/.claude/hooks/subagent-chain.sh`의 `notify()` 함수를 교체할 수 있습니다:

```bash
# Slack 웹훅
curl -s -X POST "$SLACK_WEBHOOK_URL" -d "{\"text\":\"${title}: ${body}\"}" &

# ntfy.sh (셀프 호스팅 또는 퍼블릭)
curl -s -d "${body}" "ntfy.sh/my-squad-topic" &

# terminal-notifier (macOS, 옵션 더 많음)
terminal-notifier -title "${title}" -message "${body}" -sound default &
```

---

## 커맨드

| 커맨드 | 예시 |
|--------|------|
| `/squad-review` | `/squad-review src/auth/` |
| `/squad-plan` | `/squad-plan payment system` |
| `/squad-refactor` | `/squad-refactor src/utils/` |
| `/squad-qa` | `/squad-qa` |
| `/squad-debug` | `/squad-debug TypeError: Cannot read...` |
| `/squad-docs` | `/squad-docs readme` |
| `/squad-gitops` | `/squad-gitops pr` |
| `/squad-audit` | `/squad-audit` |
| `/squad` | `/squad review src/auth/` (통합 커맨드) |

---

## 사용 예시

### 새 기능 개발

```
/squad-plan user profile editing       → 기획
[구현]                                  → 코드 작성
/squad-review                          → REQUEST_CHANGES
/squad-refactor src/profile/           → 리팩토링
/squad-review                          → APPROVE
/squad-qa                              → PASS
/squad-audit src/auth/                 → 보안 점검
/squad-gitops pr                       → PR 생성
```

### 프로덕션 버그

```
/squad-debug "TypeError: Cannot read properties of undefined"
[수정]
/squad-qa → /squad-gitops commit
```

### 레거시 정리

```
/squad-review src/legacy/              → 문제 식별
/squad-refactor src/legacy/utils/      → 리팩토링
/squad-qa                              → 회귀 테스트
/squad-docs readme                     → 문서 업데이트
```

---

## 모델 라우팅

| 에이전트 | 모델 | 이유 |
|---------|------|------|
| squad-review | opus | 보안·로직은 깊은 추론 필요 |
| squad-plan | opus | 설계와 엣지케이스 |
| squad-refactor | opus | 안전한 구조 변환 |
| squad-qa | sonnet | 테스트 실행·결과 정리 |
| squad-debug | opus | 근본 원인 분석 |
| squad-docs | sonnet | 코드→문서화 |
| squad-gitops | haiku | 패턴 작업, 비용 최적화 |
| squad-audit | opus | 보안은 놓치면 안 됨 |

전역 오버라이드: `export CLAUDE_CODE_SUBAGENT_MODEL=sonnet`

---

## 프로젝트별 오버라이드

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

## 제거

```bash
bash install.sh --uninstall
```

Squad Agent 파일만 `~/.claude/`에서 제거합니다. 백업 파일(`.bak`)은 유지됩니다. `settings.json`의 훅 항목은 수동으로 제거해야 합니다.

---

## 아키텍처

상세 아키텍처 문서는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)를 참고하세요.

---

## 기여

새 에이전트 추가나 개선 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

---

## 라이선스

[Apache License 2.0](LICENSE)

---

## 참고 자료

- [Claude Code Sub-agents (공식)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)
- [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice)
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
