# Squad Agent

**Claude Code sub-agent system with 8 specialized agents for automated development workflows.**

Claude Code 서브에이전트 시스템 — 리뷰, 기획, 리팩토링, QA, 디버깅, 문서, GitOps, 보안 감사를 전문 에이전트에 위임합니다.

![Squad Pipeline](docs/pipeline-diagram.svg)

---

## Quick Start / 빠른 시작

### Option 1: One-line Install (curl)

```bash
curl -sL https://raw.githubusercontent.com/villainscode/Claude-Code-Expert/main/subagents/install.sh | bash
```

### Option 2: Clone & Install

```bash
git clone https://github.com/villainscode/Claude-Code-Expert.git
cd Claude-Code-Expert/subagents
bash install.sh
```

### Option 3: Download Release

[Releases](https://github.com/villainscode/Claude-Code-Expert/releases) 페이지에서 최신 `squad-agents-vX.Y.Z.tar.gz`를 다운로드하세요.

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
| `squad-review` | Code review / 코드 리뷰 | opus | Read-only |
| `squad-plan` | Planning & wireframes / 기획 | opus | Read+Write |
| `squad-refactor` | Refactoring / 리팩토링 | opus | Read+Write |
| `squad-qa` | Testing & QA / 테스트 | sonnet | Read+Bash |
| `squad-debug` | Debugging / 디버깅 | opus | Read+Bash |
| `squad-docs` | Documentation / 문서 작성 | sonnet | Read+Write |
| `squad-gitops` | Git automation / Git 자동화 | haiku | Read+Bash |
| `squad-audit` | Security audit / 보안 감사 | opus | Read-only |

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

### SubagentStop Hook (Optional / 선택)

Enable automatic pipeline chaining by adding to `~/.claude/settings.json`:

자동 파이프라인 체이닝을 위해 `~/.claude/settings.json`에 추가:

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
tools: Read, Grep, Glob, Bash
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

This removes only Squad Agent files from `~/.claude/`. Backup files (`.bak`) are preserved.

Squad Agent 파일만 `~/.claude/`에서 제거합니다. 백업 파일(`.bak`)은 유지됩니다.

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
