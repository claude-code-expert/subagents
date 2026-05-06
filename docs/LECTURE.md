# Claude Code 서브에이전트 시스템 구축 강좌

## Squad Agent를 처음부터 만들며 배우는 서브에이전트 아키텍처

> **대상**: Claude Code를 사용하는 개발자
> **목표**: 8개 전문 서브에이전트 + 키워드 자동 라우팅 시스템을 직접 구축
> **버전 진화**: v1.0(커맨드 기반) → v1.3.0(키워드 자동 라우팅)

---

## 목차

- [1장. 서브에이전트란 무엇인가](#1장-서브에이전트란-무엇인가)
- [2장. 아키텍처 설계](#2장-아키텍처-설계)
- [3장. Step 1 — 첫 번째 에이전트 만들기](#3장-step-1--첫-번째-에이전트-만들기)
- [4장. Step 2 — 커맨드 추가하기](#4장-step-2--커맨드-추가하기)
- [5장. Step 3 — 8개 에이전트 팀 구성](#5장-step-3--8개-에이전트-팀-구성)
- [6장. Step 4 — SubagentStop 훅으로 파이프라인 체이닝](#6장-step-4--subagentstop-훅으로-파이프라인-체이닝)
- [7장. Step 5 — 크로스 플랫폼 알림](#7장-step-5--크로스-플랫폼-알림)
- [8장. Step 6 — UserPromptSubmit 훅으로 키워드 자동 라우팅](#8장-step-6--userpromptsubmit-훅으로-키워드-자동-라우팅)
- [9장. Step 7 — 설치 스크립트](#9장-step-7--설치-스크립트)
- [10장. Step 8 — 테스트와 CI/CD](#10장-step-8--테스트와-cicd)
- [11장. 커스터마이징 가이드](#11장-커스터마이징-가이드)
- [부록](#부록)

---

# 1장. 서브에이전트란 무엇인가

## 1.1 Claude Code의 Agent 도구

Claude Code에는 **Agent 도구**가 내장되어 있다. 이 도구를 사용하면 별도의 AI 컨텍스트(서브에이전트)를 생성하여 작업을 위임할 수 있다.

```
Agent(subagent_type="squad-review", prompt="src/ 디렉토리의 최근 변경사항을 리뷰해줘")
```

서브에이전트는 **독립된 컨텍스트 윈도우**에서 실행된다. 메인 세션과 완전히 분리된 별도의 AI 세션이 생성되고, 작업이 끝나면 요약 결과만 메인으로 돌아온다.

### bash 실행과의 차이

| 구분 | `claude -p` (bash) | Agent 도구 (서브에이전트) |
|------|-------------------|----------------------|
| 컨텍스트 | 완전히 새로운 프로세스 | 메인과 연결된 하위 에이전트 |
| 도구 접근 | 전체 도구 사용 가능 | Frontmatter로 제한 가능 |
| 모델 선택 | 환경변수로 설정 | Frontmatter `model` 필드 |
| 결과 반환 | stdout 텍스트 | 구조화된 에이전트 응답 |
| 상태 추적 | 없음 | SubagentStart/Stop 이벤트 |

## 1.2 서브에이전트를 왜 쓰는가

### 1) 컨텍스트 격리

30,000줄짜리 `git diff`를 분석한다고 하자. 메인 세션에서 직접 하면 그 diff 전체가 컨텍스트에 남아서 이후 모든 대화의 품질이 떨어진다. 서브에이전트에서 하면? 분석이 끝나고 **요약만 돌아온다**. 메인 컨텍스트는 깨끗하게 유지된다.

```
[메인 세션]                    [서브에이전트]
                               ┌─────────────────┐
"코드 리뷰해줘"  ──────────►  │ git diff 30k줄   │
                               │ 분석...           │
                               │ 이슈 3건 발견     │
◄── "3건의 이슈 발견"  ◄────  └─────────────────┘
                               (컨텍스트 소멸)
[메인 컨텍스트: 깨끗]
```

### 2) 도구 제한 (하드 제약)

프롬프트에 "파일을 수정하지 마세요"라고 써도 AI는 가끔 수정한다. 하지만 Frontmatter의 `tools` 필드에 `Read, Glob, Grep`만 넣으면? **Write, Edit 도구 자체가 없다**. 물리적으로 수정이 불가능하다.

```yaml
# 프롬프트 수준 제한 (소프트) — 가끔 무시됨
"절대 파일을 수정하지 마세요"

# 도구 수준 제한 (하드) — 무시 불가
tools: Read, Bash, Glob, Grep   # Write, Edit이 없으므로 수정 자체가 불가능
```

### 3) 모델 라우팅

모든 작업에 가장 비싼 모델을 쓸 필요가 없다. 커밋 메시지 생성은 haiku면 충분하고, 보안 감사는 opus가 필요하다. 에이전트별로 모델을 지정하면 **비용을 최적화**하면서 **품질은 유지**할 수 있다.

### 4) 병렬 실행

여러 에이전트를 동시에 띄울 수 있다. 코드 리뷰, 테스트, 보안 감사를 병렬로 실행하면 시간이 단축된다.

## 1.3 이 강좌에서 만들 것

이 강좌에서는 **Squad Agent**라는 이름의 서브에이전트 시스템을 처음부터 구축한다.

**최종 결과물:**

| 구성 요소 | 수량 | 설명 |
|-----------|------|------|
| 에이전트 | 8개 | review, plan, refactor, qa, debug, docs, gitops, audit |
| 커맨드 | 9개 | 개별 8개 + 통합 /squad |
| 훅 | 2개 | 파이프라인 체이닝 + 키워드 자동 라우팅 |
| 설치 스크립트 | 1개 | 원클릭 설치/제거 |
| 테스트 | 145+ | 키워드 라우팅 + 파일 무결성 |

**버전 진화 로드맵:**

```
v1.0  ──► 8개 에이전트 + 9개 커맨드 + SubagentStop 훅
           사용자가 /squad-review 같은 명령어를 직접 입력

v1.3.0 ──► UserPromptSubmit 훅 추가 (키워드 자동 라우팅)
           "코드 리뷰해줘" → 자동으로 squad-review 호출
           80개 키워드 (한국어 42 / 영어 38)

v1.3.2 ──► 145개 자동화 테스트 + CI/CD
```

---

# 2장. 아키텍처 설계

> 구현에 들어가기 전 전체 그림을 먼저 그린다. 이 장의 내용이 머릿속에 있어야 이후 각 Step에서 "지금 전체 중 어디를 만들고 있는지" 알 수 있다.

## 2.1 설계 결정 3가지

### 결정 1: 컨텍스트 격리 — "무거운 분석은 밖에서"

코드 리뷰, 보안 감사, 디버깅 같은 작업은 수천 줄의 코드를 읽어야 한다. 이걸 메인 세션에서 하면 컨텍스트가 빠르게 차서 이후 대화 품질이 떨어진다. 서브에이전트에서 하면 **요약만** 메인으로 돌아온다.

### 결정 2: 도구 스코핑 — "프롬프트가 아닌 물리적 제약"

에이전트마다 허용 도구를 다르게 설정한다. `squad-review`는 Read-only 도구만 가지고 있어서 **파일을 수정할 수 없다**. 이것은 프롬프트의 "하지 마세요"보다 훨씬 강력한 안전장치다.

### 결정 3: 모델 라우팅 — "작업 난이도에 맞는 모델"

| 모델 | 용도 | 에이전트 |
|------|------|---------|
| **opus** | 복잡한 추론, 보안, 아키텍처 | review, plan, refactor, debug, audit |
| **sonnet** | 실행 + 구조화 | qa, docs |
| **haiku** | 패턴 작업, 비용 최적화 | gitops |

## 2.2 디렉토리 구조

```
~/.claude/
├── agents/                     ← 에이전트 정의 (.md)
│   ├── squad-review.md
│   ├── squad-plan.md
│   ├── squad-refactor.md
│   ├── squad-qa.md
│   ├── squad-debug.md
│   ├── squad-docs.md
│   ├── squad-gitops.md
│   └── squad-audit.md
├── commands/                   ← 슬래시 커맨드 정의 (.md)
│   ├── squad.md               ← 통합 커맨드
│   ├── squad-review.md
│   ├── squad-plan.md
│   └── ... (8개)
├── hooks/                      ← 자동화 훅 (.sh)
│   ├── squad-router.sh        ← 키워드 자동 라우팅 (v1.3.0)
│   └── subagent-chain.sh      ← 파이프라인 체이닝 (v1.0)
└── settings.json               ← 훅 등록
```

**프로젝트별 오버라이드**: 프로젝트 루트의 `.claude/agents/squad-review.md`가 전역 `~/.claude/agents/squad-review.md`보다 우선한다.

## 2.3 파이프라인 아키텍처

### 코어 파이프라인

```
squad-plan → [구현] → squad-review → squad-qa → squad-gitops
  opus          사람      opus           sonnet      haiku
  R+W                     R-only         R+Bash      R+Bash
```

### 리뷰-리팩터 루프

```
squad-review
    │
    ├─ APPROVE ──────────► squad-qa → squad-gitops
    │
    └─ REQUEST_CHANGES ──► squad-refactor
                                │
                                └──► squad-review (재검증)
```

### 전체 구조

```
┌─── 코어 파이프라인 ───────────────────────────────────────┐
│                                                            │
│  squad-plan → [구현] → squad-review → squad-qa → squad-gitops  │
│    opus                  opus  ◄──┐    sonnet      haiku   │
│    R+W                   R-only   │    R+Bash      R+Bash  │
│                                   │                        │
│                            squad-refactor                  │
│                              opus / R+W                    │
│                                                            │
├─── 온디맨드 ──────────────────────────────────────────────┤
│  squad-debug (opus)   squad-docs (sonnet)   squad-audit (opus) │
│  R+Bash               R+W                   R-only        │
└────────────────────────────────────────────────────────────┘
```

### 관심사 분리

- `squad-review`: 이슈를 **찾기만** 한다 (Read-only)
- `squad-refactor`: 이슈를 **고친다** (Write 권한)
- `squad-qa`: 수정이 맞는지 **검증한다** (Bash로 테스트 실행)

이 분리가 왜 중요한가? 하나의 에이전트가 "문제 발견 → 수정 → 테스트"를 모두 하면, 자기가 만든 문제를 자기가 검증하게 된다. 역할을 분리하면 **체크앤밸런스**가 작동한다.

## 2.4 도구 권한 매트릭스

| 유형 | 도구 | 에이전트 |
|------|------|---------|
| Read-only | `Read, Bash, Glob, Grep` | review, debug, audit, gitops |
| Write (no Bash) | `Read, Write, Edit, Glob, Grep` | docs |
| Write + Bash | `Read, Write, Edit, Bash, Glob, Grep` | plan, refactor |

**도구 순서 규칙**: 모든 에이전트가 동일한 순서(`Read, Write, Edit, Bash, Glob, Grep`)를 따른다. 일관성은 유지보수를 쉽게 만든다.

**Bash 접근 에이전트의 추가 제한**: Bash를 가진 에이전트는 반드시 다음 두 섹션을 포함한다:

```markdown
## Allowed Commands
git diff, git log, grep, cat, wc

## NEVER Run
npm, rm, mv, git commit, git push
```

---

# 3장. Step 1 — 첫 번째 에이전트 만들기

> **이 단계의 목표**: 하나의 에이전트가 동작하면 나머지 7개도 같은 패턴으로 만들 수 있다. 패턴을 익히는 것이 핵심이다.

## 3.1 에이전트 정의 파일 스키마

에이전트는 `~/.claude/agents/` 디렉토리에 `.md` 파일로 정의한다. 파일 구조는 **YAML Frontmatter + 시스템 프롬프트** 두 부분으로 나뉜다.

```markdown
---
(YAML Frontmatter — 메타데이터)
---

(시스템 프롬프트 — 마크다운)
```

### Frontmatter 필드 레퍼런스

| 필드 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `name` | 예 | — | 에이전트 ID. `Agent(subagent_type="이 값")` |
| `description` | 예 | — | 자동 위임 트리거. `PROACTIVELY` 키워드 포함 시 Claude가 자동 호출 |
| `tools` | 아니오 | 상속 | 쉼표 구분. 허용 도구 목록. 여기 없는 도구는 사용 불가 |
| `model` | 아니오 | inherit | `haiku`, `sonnet`, `opus`, `inherit` 중 택 1 |
| `maxTurns` | 아니오 | — | 최대 턴 수. 무한 루프 방지용 안전장치 |
| `permissionMode` | 아니오 | — | `plan`, `acceptEdits`, `bypassPermissions` |
| `memory` | 아니오 | — | `user`, `project`, `local` |
| `background` | 아니오 | false | 백그라운드 실행 여부 |
| `skills` | 아니오 | — | 사전 로드할 스킬 목록 |
| `mcpServers` | 아니오 | — | 에이전트 전용 MCP 서버 |
| `hooks` | 아니오 | — | 에이전트 전용 훅 |

### 핵심 필드 상세

**`description`이 가장 중요하다.** Claude Code는 이 필드를 읽고 "이 에이전트를 언제 사용할지" 판단한다. `Use PROACTIVELY when...`이라고 쓰면 Claude가 사용자의 요청을 분석해서 자동으로 이 에이전트를 호출할 수 있다.

```yaml
description: >
  Expert code review agent. Use PROACTIVELY after code changes, commits,
  or when user says "리뷰", "review", "코드 리뷰".
  Pipeline: after implementation. APPROVE → /squad-qa, REQUEST_CHANGES → /squad-refactor
```

이 description에는 3가지 정보가 들어간다:

1. **역할 요약**: "Expert code review agent"
2. **트리거 조건**: "Use PROACTIVELY when... 리뷰, review, 코드 리뷰"
3. **파이프라인 위치**: "APPROVE → /squad-qa, REQUEST_CHANGES → /squad-refactor"

## 3.2 시스템 프롬프트 작성 원칙

Frontmatter 아래의 마크다운 본문이 시스템 프롬프트가 된다. 다음 구조를 권장한다:

```markdown
---
(frontmatter)
---

(1) 역할 정의 — 한 문장으로 에이전트의 정체성 선언
(2) 프로세스 — 번호 매긴 단계별 작업 절차
(3) Rules — 반드시 지켜야 할 규칙
(4) Allowed Commands / NEVER Run — Bash 접근 에이전트만
(5) Boundaries — Will / Will Not 명시
(6) Output Format — 출력 형식 템플릿
```

**Boundaries 섹션**이 특히 중요하다. "Will"과 "Will Not"을 명시하면 에이전트 간 역할 침범을 방지한다:

```markdown
## Boundaries

**Will:**
- 코드 변경사항을 읽고 분석
- Read-only git 명령어로 컨텍스트 수집

**Will Not:**
- 파일 수정 (→ /squad-refactor)
- 테스트 실행 (→ /squad-qa)
- 커밋이나 푸시 (→ /squad-gitops)
```

## 3.3 실전 예시: squad-review.md

아래는 실제 `squad-review` 에이전트의 전체 정의이다.

> **참고**: 실제 파일에서는 `Allowed Commands`, `NEVER Run`, `Output Format` 섹션 내부에 코드 펜스(``` ` ``` ` ``` `)가 감싸져 있으나, 마크다운 중첩 렌더링 한계로 아래 예시에서는 생략했다. 실제 파일을 참조할 것.

```markdown
---
name: squad-review
description: >
  Expert code review agent. Use PROACTIVELY after code changes, commits,
  or when user says "리뷰", "review", "코드 리뷰", "PR 리뷰", "코드 봐줘".
  Reviews for security, performance, maintainability, and style.
  Pipeline: after implementation. APPROVE → /squad-qa, REQUEST_CHANGES → /squad-refactor
tools: Read, Bash, Glob, Grep
model: opus
maxTurns: 15
---

You are a senior staff engineer conducting thorough code reviews.
Your reviews are concise, actionable, and prioritized by severity.

## Review Process

1. Run `git diff HEAD~1` (or `git diff --staged` if changes are staged) to identify modified files.
2. For each modified file, read the full file to understand context around changes.
3. Analyze changes across these dimensions:
   - **Critical**: Security vulnerabilities, data leaks, race conditions
   - **High**: Performance regressions, logic errors, missing error handling
   - **Medium**: Code duplication, poor naming, missing types
   - **Low**: Style inconsistencies, minor refactoring opportunities

## Rules

- NEVER modify any files. You are read-only.
- If you need to suggest a fix, show the code snippet but do NOT write it.
- Focus on the DIFF, not the entire codebase.
- Skip trivially correct changes (imports, formatting-only).

## Allowed Commands

git diff, git log, git show, git status
grep, cat, wc, find, head, tail

## NEVER Run

npm, rm, mv, git commit, git push
Any write or destructive operation

## Boundaries

**Will:**
- Read and analyze code changes for bugs, security issues, and quality
- Run read-only git and grep commands for context

**Will Not:**
- Modify any files (→ /squad-refactor)
- Run tests (→ /squad-qa)
- Commit or push changes (→ /squad-gitops)

## Output Format

## Code Review Summary

**Files Reviewed**: [count]
**Overall Assessment**: APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION

### Critical Issues
- [ ] `file:line` — Description — Why it matters — Suggested fix

### High Priority
- [ ] `file:line` — Description — Suggested fix

### Medium Priority
- [ ] `file:line` — Description

### Positive Highlights
- `file:line` — Good pattern worth noting

### Summary
[2-3 sentence overall assessment]
```

**관찰 포인트:**

- `tools: Read, Bash, Glob, Grep` — Write, Edit이 없으므로 파일 수정 자체가 불가능
- `model: opus` — 보안/로직 분석에는 가장 강력한 모델 사용
- `maxTurns: 15` — 무한 루프 방지
- Output Format에 체크박스(`- [ ]`)를 포함하여 추적 가능하게 함

## 3.4 설치 위치와 검증

```bash
# 에이전트 파일 복사
cp squad-review.md ~/.claude/agents/squad-review.md

# Claude Code에서 확인
# /agents 명령어 실행 → squad-review가 목록에 보이는지 확인
```

검증 방법:

```
# Claude Code 세션에서 직접 호출
Agent(subagent_type="squad-review", prompt="src/ 디렉토리 변경사항을 리뷰해줘")
```

---

# 4장. Step 2 — 커맨드 추가하기

> **이 단계의 목표**: 에이전트가 존재하지만 사용자가 쉽게 호출할 인터페이스가 없다. `/squad-review` 같은 슬래시 커맨드가 그 인터페이스다.

## 4.1 커맨드 정의 스키마

커맨드는 `~/.claude/commands/` 디렉토리에 `.md` 파일로 정의한다. 에이전트와 마찬가지로 Frontmatter + 본문 구조다.

```markdown
---
description: "커맨드 설명. Usage: /squad-review [scope]"
allowed-tools: Agent
---

(본문: Claude에게 전달되는 지시문)

$ARGUMENTS
```

### 핵심 필드

| 필드 | 설명 |
|------|------|
| `description` | 커맨드 목록에 표시되는 설명 |
| `allowed-tools` | 이 커맨드가 사용할 수 있는 도구. `Agent`를 넣어야 서브에이전트 호출 가능 |
| `$ARGUMENTS` | 사용자가 커맨드 뒤에 입력한 텍스트가 이 변수로 치환됨 |

### 개별 커맨드 구조

각 `/squad-*` 커맨드는 해당 에이전트를 호출하는 간단한 지시문이다:

```markdown
---
description: "코드 리뷰 실행. Usage: /squad-review [scope]"
allowed-tools: Agent
---

Invoke the squad-review agent with the following request.
If no scope is specified, review the latest git changes.

$ARGUMENTS
```

## 4.2 통합 커맨드 /squad

8개 커맨드를 각각 기억하기 어려울 수 있으므로, `/squad` 하나로 모든 에이전트를 호출할 수 있는 통합 커맨드를 만든다.

```markdown
---
description: "Invoke a Squad Agent. Usage: /squad <member> [task]"
allowed-tools: Agent
---

Parse the user's input:
- First word = member keyword (review, plan, refactor, qa, debug, docs, gitops, audit)
- Remaining text = task description

The actual agent name is `squad-{keyword}`. For example:
- "/squad review" → invoke squad-review
- "/squad refactor src/utils/" → invoke squad-refactor with scope

Available Squad Agents:
- squad-review: Code review (security, performance, style)
- squad-plan: Feature planning, user stories, wireframes
- squad-refactor: Code refactoring (extract, simplify, rename, remove)
- squad-qa: Run tests and generate QA report
- squad-debug: Error analysis and root cause identification
- squad-docs: Documentation generation and updates
- squad-gitops: Commit messages, PR descriptions, changelogs
- squad-audit: Security audit and vulnerability scanning

If no match, list all members and ask to choose.

$ARGUMENTS
```

**사용 예시:**
```
/squad review                    → squad-review 호출
/squad refactor src/utils/       → squad-refactor 호출 (scope 전달)
/squad debug "TypeError at line 42" → squad-debug 호출
```

---

# 5장. Step 3 — 8개 에이전트 팀 구성

> **이 단계의 목표**: 첫 번째 에이전트와 동일한 패턴으로 나머지 7개를 만든다. 핵심은 각 에이전트의 **역할 분리 원칙**과 **도구/모델 선택 이유**다.

## 5.1 역할 분리 원칙

두 가지 축으로 에이전트를 분류한다:

**축 1: 읽기 vs 쓰기**
- Read-only 에이전트: 분석만 한다 (review, debug, audit, gitops, qa)
- Write 에이전트: 파일을 수정한다 (plan, refactor, docs)

**축 2: 코어 파이프라인 vs 온디맨드**
- 코어: plan → review → qa → gitops (매 개발 사이클마다 순서대로)
- 온디맨드: debug, audit, docs (필요할 때만)

## 5.2 에이전트별 설계 요약

| 에이전트 | 역할 | 모델 | 도구 | 핵심 제약 |
|---------|------|------|------|----------|
| **squad-review** | 코드 리뷰 (보안, 성능, 유지보수성) | opus | Read, Bash, Glob, Grep | Read-only. APPROVE / REQUEST_CHANGES 판정 |
| **squad-plan** | 기획, 와이어프레임, 유저스토리 | opus | Read, Write, Edit, Bash, Glob, Grep | 소스 코드 수정 금지. docs/ 하위에만 작성 |
| **squad-refactor** | 안전한 코드 리팩토링 | opus | Read, Write, Edit, Bash, Glob, Grep | 작업 전 `git stash` 자동 실행. 모듈 범위 제한 |
| **squad-qa** | 테스트, 빌드, 린트 검증 | sonnet | Read, Bash, Glob, Grep | `timeout 120`으로 행 방지. 코드 수정 불가 |
| **squad-debug** | 에러 원인 분석 | opus | Read, Bash, Glob, Grep | Read-only 진단. 6단계 방법론 |
| **squad-docs** | 문서 생성 (README, API docs, JSDoc) | sonnet | Read, Write, Edit, Glob, Grep | 소스 코드 로직 수정 금지 |
| **squad-gitops** | 커밋 메시지, PR, 체인지로그 | haiku | Read, Bash, Glob, Grep | 비용 최적화. Conventional Commits 형식 |
| **squad-audit** | 보안 감사 (OWASP, 시크릿, 의존성) | opus | Read, Bash, Glob, Grep | Read-only. LOW~CRITICAL 위험도 분류 |

## 5.3 모델 라우팅 전략

```
opus   ────── 복잡한 추론이 필요한 작업
               review: 보안/로직 버그 → 놓치면 안 됨
               plan: 아키텍처 설계 → 엣지 케이스 고려
               refactor: 코드 구조 이해 + 안전한 변환
               debug: 근본 원인 분석
               audit: 보안 취약점 → 놓치면 안 됨

sonnet ────── 실행 + 구조화 작업
               qa: 테스트 실행 + 결과 정리
               docs: 코드 → 문서 변환

haiku  ────── 패턴 기반 작업 (비용 최적화)
               gitops: Conventional Commits 패턴
```

**전역 오버라이드**: 비용이 걱정되면 환경변수로 모든 서브에이전트의 모델을 일괄 변경할 수 있다:

```bash
export CLAUDE_CODE_SUBAGENT_MODEL=sonnet
```

## 5.4 프로젝트별 오버라이드

전역 에이전트 정의를 프로젝트별로 덮어쓸 수 있다. 프로젝트 루트에 `.claude/agents/squad-review.md`를 만들면 `~/.claude/agents/squad-review.md`보다 우선한다.

```
우선순위:
프로젝트/.claude/agents/squad-review.md  >  ~/.claude/agents/squad-review.md
```

활용 예시: 특정 프로젝트에서 TypeScript `any` 사용을 금지하고 싶다면, 프로젝트용 squad-review에 그 규칙을 추가한다.

---

# 6장. Step 4 — SubagentStop 훅으로 파이프라인 체이닝

> **이 단계의 목표**: 에이전트가 끝나면 "다음에 뭘 해야 하지?" 자동 안내. 에이전트 간 파이프라인을 안내하는 체이닝 훅을 만든다.

## 6.1 Claude Code 훅 시스템 개요

Claude Code는 특정 이벤트가 발생할 때 외부 스크립트를 실행하는 **훅 시스템**을 제공한다.

### 훅 이벤트 종류

| 이벤트 | 발생 시점 | 용도 |
|--------|----------|------|
| `UserPromptSubmit` | 사용자가 프롬프트를 제출할 때 | 프롬프트 분석, 컨텍스트 주입 |
| `SubagentStart` | 서브에이전트가 시작될 때 | 알림, 로깅 |
| `SubagentStop` | 서브에이전트가 종료될 때 | 알림, 다음 단계 안내 |

### 훅 동작 원리

```
[이벤트 발생]
    │
    ▼
[Claude Code가 stdin으로 JSON 전달]
    │
    ▼
[훅 스크립트 실행]
    │
    ▼
[stdout으로 JSON 응답 (선택)]
```

- **입력**: stdin으로 JSON 객체 수신
- **출력**: stdout으로 JSON 응답 (선택적)
- **등록**: `~/.claude/settings.json`의 `hooks` 섹션

### settings.json 등록 구조

```jsonc
{
  "hooks": {
    "SubagentStop": [
      {
        "matcher": "",          // 빈 문자열 = 모든 이벤트에 매칭
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

## 6.2 subagent-chain.sh — 전체 코드

```bash
#!/usr/bin/env zsh
# subagent-chain.sh — Squad Agent notification + pipeline chaining hook
# Handles both SubagentStart and SubagentStop events
# Registered automatically by install.sh
#
# Cross-platform: macOS (osascript), Linux (notify-send), Windows/WSL (powershell)
# Claude Code is a TUI app — stdout/stderr from SubagentStart/Stop hooks
# are not displayed in the terminal. OS-native notifications are used instead.
set -uo pipefail

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

EVENT=$(jq -r '.hook_event_name // empty' < "$TMPFILE")
AGENT_NAME=$(jq -r '.agent_type // .agent_name // empty' < "$TMPFILE")

# Only handle squad-* agents
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac

DISPLAY_NAME="${AGENT_NAME#squad-}"

# --- Cross-platform notification ---
notify() {
  local title="$1" body="$2"

  case "$(uname -s)" in
    Darwin)
      osascript -e "display notification \"${body}\" with title \"${title}\"" 2>/dev/null &
      ;;
    Linux)
      if command -v notify-send &>/dev/null; then
        notify-send "${title}" "${body}" 2>/dev/null &
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      powershell.exe -Command "[void](New-Object -ComObject Wscript.Shell).Popup('${body}',3,'${title}',64)" 2>/dev/null &
      ;;
  esac

  # WSL detection (Linux kernel but Windows host)
  if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    powershell.exe -Command "[void](New-Object -ComObject Wscript.Shell).Popup('${body}',3,'${title}',64)" 2>/dev/null &
  fi
}

play_sound() {
  local sound_name="$1"

  case "$(uname -s)" in
    Darwin)
      afplay "/System/Library/Sounds/${sound_name}.aiff" 2>/dev/null &
      ;;
    Linux)
      if command -v paplay &>/dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/message.oga 2>/dev/null &
      elif command -v aplay &>/dev/null; then
        aplay /usr/share/sounds/sound-icons/xylofon.wav 2>/dev/null &
      fi
      ;;
  esac
}

# --- Event handling ---
if [ "$EVENT" = "SubagentStart" ]; then
  notify "🚀 Squad: ${DISPLAY_NAME}" "Status: RUNNING"
  play_sound "Pop"

elif [ "$EVENT" = "SubagentStop" ]; then
  NEXT=""
  case "$AGENT_NAME" in
    "squad-plan")    NEXT="→ implement, then /squad-review" ;;
    "squad-review")  NEXT="→ /squad-refactor or /squad-qa" ;;
    "squad-refactor") NEXT="→ /squad-review to verify" ;;
    "squad-qa")      NEXT="→ /squad-gitops commit" ;;
    "squad-debug")   NEXT="→ implement the fix" ;;
    "squad-docs")    NEXT="Documentation updated." ;;
    "squad-gitops")  NEXT="Git artifacts generated." ;;
    "squad-audit")   NEXT="Address findings before deploy." ;;
  esac
  notify "✅ Squad: ${DISPLAY_NAME}" "COMPLETED ${NEXT}"
  play_sound "Glass"
fi

exit 0
```

## 6.3 코드 해설

### stdin JSON 읽기 패턴

```bash
TMPFILE=$(mktemp)           # 임시 파일 생성
trap 'rm -f "$TMPFILE"' EXIT # 스크립트 종료 시 자동 삭제
cat > "$TMPFILE"             # stdin 전체를 임시 파일에 저장
```

**왜 임시 파일을 쓰는가?** stdin은 한 번만 읽을 수 있다. 여러 번 파싱해야 하므로(EVENT, AGENT_NAME) 파일로 저장해두고 재사용한다.

### jq guard 패턴

```bash
if ! command -v jq &>/dev/null; then exit 0; fi   # jq 없으면 조용히 종료
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi  # 유효하지 않은 JSON이면 종료
```

**원칙: 훅은 절대로 에러를 발생시키면 안 된다.** jq가 설치되지 않았거나 입력이 잘못되었으면 조용히 종료한다. 훅 에러가 Claude Code 전체를 멈추게 할 수 있기 때문이다.

### squad-* 필터링

```bash
case "$AGENT_NAME" in squad-*) ;; *) exit 0 ;; esac
```

다른 서브에이전트(예: Explore, Plan 등 Claude Code 내장 에이전트)가 실행될 때도 이 훅이 호출된다. squad-* 에이전트가 아니면 무시한다.

### 체이닝 로직 (NEXT 변수)

```bash
case "$AGENT_NAME" in
  "squad-plan")    NEXT="→ implement, then /squad-review" ;;
  "squad-review")  NEXT="→ /squad-refactor or /squad-qa" ;;
  "squad-refactor") NEXT="→ /squad-review to verify" ;;
  "squad-qa")      NEXT="→ /squad-gitops commit" ;;
  ...
esac
```

에이전트 종료 시 다음 단계를 알림으로 보여준다. **자동 실행이 아니라 안내**라는 점이 중요하다. 사용자가 판단하고 다음 에이전트를 수동으로 호출한다.

---

# 7장. Step 5 — 크로스 플랫폼 알림

> **이 단계의 목표**: 서브에이전트 작업은 수 분이 소요된다. "끝났습니다" 알림이 없으면 사용자가 계속 화면을 주시해야 한다.

## 7.1 왜 OS 알림인가

Claude Code는 **TUI(터미널 UI) 앱**이다. `SubagentStart`/`SubagentStop` 훅에서 `echo`로 출력해도 사용자 화면에 보이지 않는다. 유일한 방법은 **OS 네이티브 알림**이다.

## 7.2 플랫폼별 알림 메커니즘

| 플랫폼 | 알림 API | 사운드 API |
|--------|---------|-----------|
| macOS | `osascript -e "display notification ..."` | `afplay /System/Library/Sounds/{name}.aiff` |
| Linux | `notify-send "{title}" "{body}"` | `paplay` 또는 `aplay` |
| Windows/WSL | `powershell.exe Wscript.Shell.Popup(...)` | — |

## 7.3 notify() 함수 심층 분석

```bash
notify() {
  local title="$1" body="$2"

  case "$(uname -s)" in
    Darwin)
      osascript -e "display notification \"${body}\" with title \"${title}\"" 2>/dev/null &
      ;;
    Linux)
      if command -v notify-send &>/dev/null; then
        notify-send "${title}" "${body}" 2>/dev/null &
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      powershell.exe -Command "..." 2>/dev/null &
      ;;
  esac

  # WSL 감지
  if [ -f /proc/version ] && grep -qi microsoft /proc/version 2>/dev/null; then
    powershell.exe -Command "..." 2>/dev/null &
  fi
}
```

**핵심 설계 결정:**

1. **`&` (백그라운드 실행)**: 알림 명령어가 느려도 훅 자체를 블로킹하지 않는다
2. **`2>/dev/null`**: 알림 실패가 에러를 발생시키지 않는다. 알림은 "있으면 좋은 것"이지 필수가 아니다
3. **WSL 별도 감지**: WSL은 `uname -s`가 `Linux`를 반환하지만 실제로는 Windows 호스트다. `/proc/version`에 "microsoft"가 포함되는지 확인하여 PowerShell 알림을 추가로 보낸다
4. **`command -v` 체크**: `notify-send`가 설치되지 않은 Linux에서도 에러 없이 넘어간다

---

# 8장. Step 6 — UserPromptSubmit 훅으로 키워드 자동 라우팅

> **이 장이 전체 강좌의 핵심이다.** v1(커맨드)에서 v2(자동 라우팅)로의 질적 전환점이다.

## 8.1 v1 vs v2 — 사용자 경험의 변화

### v1: 커맨드 기반

```
사용자: /squad-review src/

→ 사용자가 에이전트 이름을 기억하고 직접 입력해야 한다
→ 슬래시 커맨드 9개를 외워야 한다
```

### v2: 키워드 자동 라우팅

```
사용자: 이 코드 리뷰해줘

→ "리뷰" 키워드 감지 → 자동으로 squad-review 호출
→ 사용자는 자연어로 말하기만 하면 된다
```

**사용자 입장에서 서브에이전트의 존재를 몰라도 된다.** 이것이 v2의 핵심 가치다.

## 8.2 UserPromptSubmit 훅의 메커니즘

### 동작 흐름

```
사용자 프롬프트 입력
    │
    ▼
UserPromptSubmit 훅 실행 (Claude가 프롬프트를 처리하기 전)
    │
    ▼
squad-router.sh가 키워드 감지
    │
    ├─ 키워드 없음 → 아무 출력 없이 종료 → Claude가 직접 처리
    │
    └─ 키워드 발견 → JSON 출력:
        {
          "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "[Squad Router] MUST delegate to squad-review..."
          }
        }
        │
        ▼
    Claude가 이 컨텍스트를 system-reminder로 수신
        │
        ▼
    Claude가 해당 서브에이전트를 호출
```

### 핵심 원리: additionalContext

`hookSpecificOutput.additionalContext`에 넣은 텍스트는 Claude에게 **system-reminder**로 전달된다. 이것은 사용자 프롬프트를 수정하는 것이 아니라, Claude가 프롬프트를 처리할 때 추가 컨텍스트로 참고하게 만드는 것이다.

```
프롬프트 자체: "이 코드 리뷰해줘" (변경 없음)
추가 컨텍스트: "[Squad Router] MUST delegate to squad-review subagent" (주입됨)
```

## 8.3 squad-router.sh — 전체 코드

```bash
#!/bin/bash
# squad-router.sh — Keyword-based subagent routing hook
# Triggered by UserPromptSubmit: detects keywords in user prompts
# and injects subagent delegation context via stdout.
#
# Registered automatically by install.sh
# See docs/SQUAD-ROUTER-KEYWORDS.md for keyword reference
#
# Opt-out:
#   Per-prompt: add --no-route or #direct to your prompt
#   Global:     export SQUAD_ROUTER=off
set -euo pipefail

# --- Env-level kill switch ---
if [ "${SQUAD_ROUTER:-}" = "off" ]; then
  exit 0
fi

# --- Read stdin (JSON from Claude Code) ---
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat > "$TMPFILE"

# --- jq guard ---
if ! command -v jq &>/dev/null; then exit 0; fi
if ! jq empty < "$TMPFILE" 2>/dev/null; then exit 0; fi

PROMPT=$(jq -r '.prompt // ""' < "$TMPFILE")
if [ -z "$PROMPT" ]; then exit 0; fi

# --- Normalize to lowercase ---
LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# === Phase 1: SKIP conditions ===

# Skip slash commands (user already chose explicitly)
case "$LOWER" in
  "/"*) exit 0 ;;
esac

# Skip opt-out markers
case "$LOWER" in
  *"--no-route"*|*"#direct"*) exit 0 ;;
esac

# === Phase 2: CONFLICT resolution (multi-word patterns first) ===
AGENT=""
case "$LOWER" in
  *"pr 리뷰"*|*"pr review"*|*"테스트 코드 리뷰"*)
    AGENT="squad-review" ;;
  *"pr 작성"*|*"pr 만들"*|*"pr 써"*)
    AGENT="squad-gitops" ;;
  *"보안 리뷰"*|*"보안 검토"*|*"security review"*)
    AGENT="squad-audit" ;;
  *"에러 테스트"*|*"빌드 에러"*|*"build error"*)
    AGENT="squad-debug" ;;
  *"빌드 확인"*|*"빌드 돌"*|*"build check"*)
    AGENT="squad-qa" ;;
  *"코드 정리"*|*"code cleanup"*)
    AGENT="squad-refactor" ;;
esac

# === Phase 3: GENERAL keyword matching (priority order) ===
if [ -z "$AGENT" ]; then
  case "$LOWER" in
    # 1. squad-audit (security — highest priority)
    *"보안"*|*"security"*|*"취약점"*|*"vulnerab"*|*"audit"*|*"owasp"*|\
    *"시크릿"*|*"secret"*|*"인젝션"*|*"injection"*|*"xss"*|*"csrf"*)
      AGENT="squad-audit" ;;

    # 2. squad-debug (error/bug)
    *"디버그"*|*"debug"*|*"에러"*|*"error"*|*"버그"*|*"bug"*|\
    *"오류"*|*"크래시"*|*"crash"*|*"stack trace"*|*"traceback"*|*"exception"*)
      AGENT="squad-debug" ;;

    # 3. squad-plan (planning)
    *"기획"*|*"plan "*|*"설계해"*|*"와이어프레임"*|*"wireframe"*|\
    *"유저스토리"*|*"user story"*|*"브레인스토밍"*|*"brainstorm"*|\
    *"스펙"*|*"spec"*|*"요구사항"*|*"구현 계획"*)
      AGENT="squad-plan" ;;

    # 4. squad-refactor (refactoring)
    *"리팩토링"*|*"리팩터"*|*"refactor"*|*"클린업"*|*"cleanup"*|*"clean up"*|\
    *"추출"*|*"extract"*|*"중복 제거"*|*"코드 개선"*|*"함수 분리"*|*"컴포넌트 분리"*)
      AGENT="squad-refactor" ;;

    # 5. squad-docs (documentation)
    *"문서화"*|*"문서"*|*"document"*|*"readme"*|*"리드미"*|\
    *"jsdoc"*|*"tsdoc"*|*"주석"*|*"comment"*)
      AGENT="squad-docs" ;;

    # 6. squad-gitops (git operations)
    *"커밋"*|*"commit"*|*"체인지로그"*|*"changelog"*|\
    *"릴리즈 노트"*|*"release note"*|*"conventional"*)
      AGENT="squad-gitops" ;;

    # 7. squad-qa (test/verification)
    *"테스트"*|*"test"*|*"qa"*|*"검증"*|\
    *"린트"*|*"lint"*|*"타입체크"*|*"type check"*|*"리그레션"*|*"regression"*)
      AGENT="squad-qa" ;;

    # 8. squad-review (broadest — last)
    *"리뷰"*|*"review"*|*"코드 검토"*|*"검토해"*|*"diff 봐"*)
      AGENT="squad-review" ;;
  esac
fi

if [ -z "$AGENT" ]; then
  exit 0
fi

# === Output: inject context via hookSpecificOutput ===
CONTEXT="[Squad Router] IMPORTANT: You MUST delegate this task to the ${AGENT} subagent. Do NOT handle it directly in the main session. Invoke: Agent(subagent_type=\"${AGENT}\", prompt=\"<user's full request>\"). This is a hard requirement from the user's installed hook system."

jq -n \
  --arg ctx "$CONTEXT" \
  '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'

exit 0
```

## 8.4 코드 해설 — 3단계 매칭 구조

이 라우터의 핵심은 **3단계 매칭 구조**다. 각 단계에는 명확한 이유가 있다.

### Phase 1: SKIP — "라우팅하면 안 되는 경우"

```bash
# 슬래시 커맨드 → 사용자가 이미 명시적으로 선택했음
case "$LOWER" in
  "/"*) exit 0 ;;
esac

# 명시적 opt-out → 사용자가 라우팅을 원하지 않음
case "$LOWER" in
  *"--no-route"*|*"#direct"*) exit 0 ;;
esac
```

**3가지 스킵 경로:**
1. **슬래시 커맨드 (`/`로 시작)**: 사용자가 `/squad-review`를 직접 입력했는데 라우터가 또 개입하면 충돌
2. **`--no-route`**: 프롬프트에 추가. "이건 내가 직접 할게"
3. **`SQUAD_ROUTER=off` (환경변수)**: 전역 비활성화. 스크립트 첫 부분에서 체크

### Phase 2: CONFLICT — "여러 에이전트에 매칭될 수 있는 표현"

```bash
AGENT=""
case "$LOWER" in
  *"pr 리뷰"*|*"pr review"*)        AGENT="squad-review" ;;
  *"pr 작성"*|*"pr 만들"*|*"pr 써"*) AGENT="squad-gitops" ;;
  *"보안 리뷰"*|*"security review"*) AGENT="squad-audit" ;;
  *"빌드 에러"*|*"build error"*)     AGENT="squad-debug" ;;
  *"빌드 확인"*|*"빌드 돌"*)         AGENT="squad-qa" ;;
  *"코드 정리"*|*"code cleanup"*)    AGENT="squad-refactor" ;;
esac
```

**왜 다단어 패턴을 먼저 매칭하는가?**

"PR 리뷰"에는 "리뷰"(→ squad-review)도 있고 "PR"(→ squad-gitops)도 있다. Phase 3에서 단일 키워드로 매칭하면 우선순위에 따라 잘못된 에이전트로 갈 수 있다. 다단어 패턴을 **먼저** 매칭하면 의도를 정확히 파악할 수 있다.

| 표현 | 충돌 | Phase 2 결과 | 이유 |
|------|------|-------------|------|
| "PR 리뷰" | review vs gitops | **squad-review** | "리뷰"가 행위의 핵심 |
| "PR 작성" | review vs gitops | **squad-gitops** | "작성"이 행위의 핵심 |
| "보안 리뷰" | audit vs review | **squad-audit** | "보안"이 도메인 결정 |
| "빌드 에러" | debug vs qa | **squad-debug** | "에러"가 핵심. 원인 분석 필요 |
| "빌드 확인" | debug vs qa | **squad-qa** | "확인"은 검증. 테스트 실행 |
| "코드 정리" | refactor vs review | **squad-refactor** | "정리"는 리팩토링 |

**설계 원칙: 행위 동사가 의도를 결정한다.**

### Phase 3: GENERAL — "단일 키워드, 우선순위 순"

```bash
if [ -z "$AGENT" ]; then
  case "$LOWER" in
    # 1. squad-audit (최고 우선순위 — 보안)
    *"보안"*|*"security"*|*"취약점"*|...) AGENT="squad-audit" ;;

    # 2. squad-debug (에러/버그)
    *"디버그"*|*"debug"*|*"에러"*|...) AGENT="squad-debug" ;;

    # ... 3~7 생략 ...

    # 8. squad-review (가장 넓은 범위 — 최저 우선순위)
    *"리뷰"*|*"review"*|...) AGENT="squad-review" ;;
  esac
fi
```

**bash의 `case` 문은 first-match-wins다.** 첫 번째로 매칭되는 패턴에서 멈춘다. 이 특성을 활용하여 우선순위를 구현한다.

**우선순위 순서와 그 이유:**

| 순위 | 에이전트 | 이유 |
|------|---------|------|
| 1 | squad-audit | 보안은 최우선. "security" 키워드 발견 시 다른 건 무시 |
| 2 | squad-debug | 에러/버그는 긴급. 바로 원인 분석 |
| 3 | squad-plan | 설계/기획은 구현 전에 해야 함 |
| 4 | squad-refactor | 코드 개선은 구체적인 의도 |
| 5 | squad-docs | 문서화 요청은 명확 |
| 6 | squad-gitops | 커밋/PR은 명확한 Git 작업 |
| 7 | squad-qa | "test" 키워드가 넓어서 뒤로 |
| 8 | squad-review | "review"가 가장 범용적이므로 마지막 |

### 출력: 강제 위임 메시지

```bash
CONTEXT="[Squad Router] IMPORTANT: You MUST delegate this task to the ${AGENT} subagent. Do NOT handle it directly in the main session. Invoke: Agent(subagent_type=\"${AGENT}\", prompt=\"<user's full request>\"). This is a hard requirement from the user's installed hook system."
```

**"MUST delegate"라는 강한 어조를 쓰는 이유:** "consider using..."이나 "you might want to..."처럼 약하게 쓰면 Claude가 무시하고 직접 처리할 수 있다. "MUST"와 "hard requirement"로 강제해야 확실히 서브에이전트를 호출한다.

## 8.5 키워드 매핑 전략

### 키워드 선별 기준 3가지

1. **의도 명확성**: 이 단어가 나오면 해당 에이전트를 원하는 것이 확실한가?
2. **오탐 확률**: 일상 대화에서 이 단어가 다른 의미로 쓰일 수 있는가?
3. **사용 빈도**: 실제로 사용자가 이 표현을 쓸 가능성이 있는가?

### 에이전트별 키워드 수

총 80개 키워드 (한국어 약 41 / 영어 약 39 — 외래어 분류 기준에 따라 ±1):

| 에이전트 | Phase 3 키워드 수 | 대표 키워드 |
|---------|:-:|------|
| squad-audit | 12 | 보안, security, 취약점, xss, csrf |
| squad-debug | 12 | 디버그, error, 버그, crash, exception |
| squad-plan | 13 | 기획, plan, 와이어프레임, user story, spec |
| squad-refactor | 12 | 리팩토링, refactor, 추출, extract, clean up |
| squad-docs | 9 | 문서화, document, readme, jsdoc, 주석 |
| squad-gitops | 7 | 커밋, commit, changelog, release note |
| squad-qa | 10 | 테스트, test, lint, type check, regression |
| squad-review | 5 | 리뷰, review, 코드 검토, diff 봐 |

### 제외된 키워드와 그 이유

| 키워드 | 제외 이유 |
|--------|----------|
| `docs` | 3글자. `docs/` 경로명과 오탐 |
| `dry` | 3글자. 일반 영단어 "dry"와 오탐 |
| `fail` | "test failed" ≠ "debug this". 문맥에 따라 다름 |
| `안돼` / `안되` | 일상 대화에서 너무 빈번 ("이거 안돼?" → 단순 질문) |
| `planet` 같은 부분 매칭 | "plan " (뒤에 공백)으로 패턴을 제한하여 방지 |

### "plan " vs "planet" 문제

```bash
*"plan "*    # "plan the architecture" → 매칭 ✓
             # "planet earth" → 매칭 ✗ (공백이 없으므로)
```

`*"plan"*`으로 쓰면 "planet"도 매칭된다. 뒤에 공백을 넣어 `*"plan "*`으로 제한한다.

## 8.6 성능 고려사항

이 훅은 **모든 프롬프트 제출마다** 실행된다.

- **총 실행 시간**: ~10-15ms (jq spawn 포함)
- **무매칭 시**: 가장 빠른 경로 (Phase 1 스킵 또는 Phase 3 끝까지 no match → `exit 0`)
- **사용자 경험 영향**: 없음 (체감 불가)

---

# 9장. Step 7 — 설치 스크립트

> **이 단계의 목표**: 에이전트/커맨드/훅의 수동 복사와 settings.json 수동 편집을 자동화한다. 원클릭 설치가 채택률을 결정한다.

## 9.1 install.sh — 전체 코드

```bash
#!/bin/bash
# install.sh — Squad Agent installer (local + remote)
# Usage:
#   Local:  bash install.sh
#   Remote: curl -sL https://raw.githubusercontent.com/.../install.sh | bash
#   Remove: bash install.sh --uninstall
#   Version: bash install.sh --version
set -euo pipefail

REPO="claude-code-expert/subagents"
RELEASE_BASE="https://github.com/$REPO/releases"

# Read version from VERSION file if available (local install), else fallback
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(dirname "${BASH_SOURCE[0]}")/VERSION" ]; then
  VERSION=$(cat "$(dirname "${BASH_SOURCE[0]}")/VERSION")
else
  VERSION="1.3.1"
fi

AGENTS_DIR="$HOME/.claude/agents"
COMMANDS_DIR="$HOME/.claude/commands"
HOOKS_DIR="$HOME/.claude/hooks"

SQUAD_AGENTS=(
  squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_COMMANDS=(
  squad squad-review squad-plan squad-refactor squad-qa
  squad-debug squad-docs squad-gitops squad-audit
)
SQUAD_HOOKS=(subagent-chain.sh squad-router.sh)

# Global temp dir for cleanup
_TMPDIR=""

# ─── Helpers ──────────────────────────────────────────
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

cleanup() { if [ -n "$_TMPDIR" ]; then rm -rf "$_TMPDIR"; fi; }
trap cleanup EXIT

banner() {
  echo ""
  bold "Squad Agent Installer v$VERSION"
  echo "================================"
  echo ""
}

# ─── Uninstall ────────────────────────────────────────
uninstall() {
  banner
  yellow "Uninstalling Squad Agent..."
  echo ""

  local removed=0

  echo "Agents:"
  for name in "${SQUAD_AGENTS[@]}"; do
    local f="$AGENTS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Commands:"
  for name in "${SQUAD_COMMANDS[@]}"; do
    local f="$COMMANDS_DIR/${name}.md"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name.md"
      ((removed++)) || true
    fi
  done

  echo ""
  echo "Hooks:"
  for name in "${SQUAD_HOOKS[@]}"; do
    local f="$HOOKS_DIR/$name"
    if [ -f "$f" ]; then
      rm -f "$f"
      green "  Removed $name"
      ((removed++)) || true
    fi
  done

  echo ""
  if [ "$removed" -gt 0 ]; then
    green "Uninstalled $removed file(s). Restart Claude Code."
    yellow "Note: .bak backup files were preserved."
  else
    yellow "No Squad Agent files found."
  fi
}

# ─── Detect source directory ─────────────────────────
find_source_dir() {
  local script_dir
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$script_dir/agents" ] && [ -d "$script_dir/commands" ]; then
      echo "$script_dir"
      return 0
    fi
  fi
  return 1
}

# ─── Register hooks in settings.json ──────────────────
register_hook() {
  local settings="$HOME/.claude/settings.json"
  local hook_cmd="zsh ~/.claude/hooks/subagent-chain.sh"
  local new_hook='[{"matcher":"","hooks":[{"type":"command","command":"'"$hook_cmd"'"}]}]'

  # If jq is not available, print manual instructions
  if ! command -v jq &>/dev/null; then
    yellow "Note: jq not found — cannot auto-register hooks."
    yellow "Add SubagentStart, SubagentStop, and UserPromptSubmit hooks manually to $settings"
    return 0
  fi

  # If settings.json doesn't exist, create minimal one
  if [ ! -f "$settings" ]; then
    echo '{}' > "$settings"
  fi

  local registered=0

  # Register SubagentStart hook
  if jq -e '.hooks.SubagentStart' "$settings" &>/dev/null; then
    green "  SubagentStart hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$new_hook" '.hooks.SubagentStart = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  SubagentStart hook registered"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  # Register SubagentStop hook
  if jq -e '.hooks.SubagentStop' "$settings" &>/dev/null; then
    green "  SubagentStop hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$new_hook" '.hooks.SubagentStop = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  SubagentStop hook registered"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  # Register UserPromptSubmit hook (squad-router)
  local router_cmd="bash ~/.claude/hooks/squad-router.sh"
  local router_hook='[{"matcher":"","hooks":[{"type":"command","command":"'"$router_cmd"'"}]}]'

  if jq -e '.hooks.UserPromptSubmit' "$settings" &>/dev/null; then
    green "  UserPromptSubmit hook already registered."
  else
    local tmp
    tmp=$(mktemp)
    if jq --argjson hook "$router_hook" '.hooks.UserPromptSubmit = $hook' "$settings" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$settings"
      green "  UserPromptSubmit hook registered (squad-router)"
      ((registered++)) || true
    else
      rm -f "$tmp"
    fi
  fi

  if [ "$registered" -eq 0 ]; then
    return 0
  fi
}

# ─── Install from source directory ───────────────────
do_install() {
  local src="$1"

  mkdir -p "$AGENTS_DIR" "$COMMANDS_DIR" "$HOOKS_DIR"

  echo "Agents (${#SQUAD_AGENTS[@]}):"
  for f in "$src"/agents/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$AGENTS_DIR/$n" ]; then
      cp "$AGENTS_DIR/$n" "$AGENTS_DIR/${n}.bak"
      yellow "  Backed up $n"
    fi
    cp "$f" "$AGENTS_DIR/$n"
    green "  Installed $n"
  done

  echo ""
  echo "Commands (${#SQUAD_COMMANDS[@]}):"
  for f in "$src"/commands/*.md; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$COMMANDS_DIR/$n" ]; then
      cp "$COMMANDS_DIR/$n" "$COMMANDS_DIR/${n}.bak"
    fi
    cp "$f" "$COMMANDS_DIR/$n"
    local cmd_name="${n%.md}"
    green "  Installed /$cmd_name"
  done

  echo ""
  echo "Hooks:"
  for f in "$src"/hooks/*.sh; do
    [ -f "$f" ] || continue
    local n
    n=$(basename "$f")
    if [ -f "$HOOKS_DIR/$n" ]; then
      cp "$HOOKS_DIR/$n" "$HOOKS_DIR/${n}.bak"
    fi
    cp "$f" "$HOOKS_DIR/$n"
    chmod +x "$HOOKS_DIR/$n"
    green "  Installed $n"
  done

  # Auto-register hooks in settings.json
  register_hook

  cat << 'DONE'

================================

  Squad Agent installed!

  Next steps:
    1. Restart Claude Code
    2. Run /agents to verify
    3. Try /squad-review to start

================================

  Commands:
    /squad-review          Code review
    /squad-plan <feature>  Planning + wireframes
    /squad-refactor [scope] Refactoring
    /squad-qa              Testing + QA
    /squad-debug <error>   Debugging
    /squad-docs <type>     Documentation
    /squad-gitops <type>   Commit / PR
    /squad-audit           Security audit
    /squad <member>        Universal invoke

DONE
}

# ─── Register pre-commit hook (dev mode) ─────────────
register_precommit() {
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    yellow "Not in a git repository — skipping pre-commit hook."
    return 0
  }

  local hook_file="$repo_root/.git/hooks/pre-commit"

  if [ -f "$hook_file" ] && grep -q "test-router.sh" "$hook_file" 2>/dev/null; then
    green "  Pre-commit hook already registered."
    return 0
  fi

  mkdir -p "$repo_root/.git/hooks"
  cat > "$hook_file" << 'HOOK'
#!/bin/bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "Running squad-router tests..."
bash "$REPO_ROOT/tests/test-router.sh" --quiet || exit 1
bash "$REPO_ROOT/tests/test-files.sh" --quiet || exit 1
echo "All tests passed."
HOOK
  chmod +x "$hook_file"
  green "  Pre-commit hook installed at .git/hooks/pre-commit"
}

# ─── Main ─────────────────────────────────────────────
main() {
  case "${1:-}" in
    --uninstall|-u)
      uninstall
      ;;
    --version|-v)
      echo "Squad Agent v$VERSION"
      ;;
    --dev)
      banner
      echo "Developer mode: registering pre-commit hook..."
      register_precommit
      ;;
    --help|-h)
      echo "Usage: bash install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  (no args)      Install Squad Agent"
      echo "  --uninstall    Remove Squad Agent files"
      echo "  --dev          Register pre-commit test hook (contributors)"
      echo "  --version      Show version"
      echo "  --help         Show this help"
      ;;
    *)
      banner

      # Try local source first
      local src=""
      src=$(find_source_dir) || true

      if [ -n "$src" ]; then
        do_install "$src"
      else
        # Remote install: download latest release
        yellow "No local source found. Downloading latest release..."
        echo ""

        _TMPDIR=$(mktemp -d)

        local latest_tag
        latest_tag=$(curl -sI "$RELEASE_BASE/latest" 2>/dev/null | grep -i '^location:' | sed 's|.*/||' | tr -d '\r\n') || true

        if [ -z "$latest_tag" ]; then
          red "Error: Could not determine latest release."
          red "Please install manually: git clone https://github.com/$REPO.git && cd subagents && bash install.sh"
          exit 1
        fi

        # Validate tag format (vX.Y.Z)
        if [[ ! "$latest_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          red "Error: Invalid release tag format: $latest_tag"
          red "Expected format: vX.Y.Z (e.g., v1.1.0)"
          exit 1
        fi

        green "Latest version: $latest_tag"

        local archive_url="$RELEASE_BASE/download/$latest_tag/squad-agents-${latest_tag}.tar.gz"
        local checksum_url="$RELEASE_BASE/download/$latest_tag/squad-agents-${latest_tag}.tar.gz.sha256"
        echo "Downloading $archive_url ..."

        if ! curl -sL "$archive_url" -o "$_TMPDIR/squad.tar.gz"; then
          red "Error: Download failed."
          exit 1
        fi

        # Verify checksum if available
        if curl -sL "$checksum_url" -o "$_TMPDIR/squad.tar.gz.sha256" 2>/dev/null; then
          if command -v shasum &>/dev/null; then
            local expected actual
            expected=$(awk '{print $1}' < "$_TMPDIR/squad.tar.gz.sha256")
            actual=$(shasum -a 256 "$_TMPDIR/squad.tar.gz" | awk '{print $1}')
            if [ "$expected" != "$actual" ]; then
              red "Error: Checksum verification failed!"
              red "  Expected: $expected"
              red "  Actual:   $actual"
              red "The downloaded file may be corrupted or tampered with."
              exit 1
            fi
            green "Checksum verified."
          else
            yellow "Warning: shasum not found — skipping checksum verification."
          fi
        else
          yellow "Warning: No checksum file found — skipping verification."
        fi

        tar xzf "$_TMPDIR/squad.tar.gz" -C "$_TMPDIR"

        local extracted
        extracted=$(find "$_TMPDIR" -name "agents" -type d -maxdepth 2 | head -1) || true
        if [ -z "$extracted" ]; then
          red "Error: Invalid archive — agents/ not found."
          exit 1
        fi

        do_install "$(dirname "$extracted")"
      fi
      ;;
  esac
}

# Wrap in main() so curl|bash downloads the entire script before executing
main "$@"
```

## 9.2 핵심 함수 해설

### register_hook() — settings.json에 훅 자동 등록

이 함수가 설치 스크립트의 **가장 중요한 부분**이다. 수동으로 settings.json을 편집하는 것은 실수하기 쉽다.

```bash
# jq가 없으면 수동 안내 (graceful degradation)
if ! command -v jq &>/dev/null; then
  yellow "Note: jq not found — cannot auto-register hooks."
  return 0
fi

# 이미 등록되어 있으면 스킵 (멱등성)
if jq -e '.hooks.SubagentStart' "$settings" &>/dev/null; then
  green "  SubagentStart hook already registered."
else
  # jq로 JSON에 훅 추가
  jq --argjson hook "$new_hook" '.hooks.SubagentStart = $hook' "$settings" > "$tmp"
  mv "$tmp" "$settings"
fi
```

**3가지 설계 패턴:**

1. **Graceful degradation**: jq가 없어도 설치 자체는 성공. 훅 등록만 수동으로 안내
2. **멱등성**: 여러 번 실행해도 안전. 이미 등록된 훅은 건너뜀
3. **jq 안전 패턴**: 임시 파일에 쓰고 `mv`로 원자적 교체. 중간에 실패해도 원본 보존

### do_install() — 파일 복사 + 백업

```bash
if [ -f "$AGENTS_DIR/$n" ]; then
  cp "$AGENTS_DIR/$n" "$AGENTS_DIR/${n}.bak"   # 기존 파일 백업
  yellow "  Backed up $n"
fi
cp "$f" "$AGENTS_DIR/$n"                         # 새 파일 복사
```

기존 파일이 있으면 `.bak`으로 백업한 후 덮어쓴다. 문제가 생기면 `.bak`에서 복구할 수 있다.

### main() — curl|bash 안전 패턴

```bash
main() {
  # ... 모든 로직 ...
}

# 이 줄이 중요!
main "$@"
```

**왜 `main()` 함수로 감싸는가?**

`curl -sL ... | bash`로 실행할 때, bash는 stdin에서 스크립트를 **한 줄씩** 읽으면서 실행한다. 네트워크가 느리면 스크립트 다운로드 중간에 실행이 시작될 수 있다. `main()` 함수로 감싸면 **전체 스크립트가 다운로드된 후** `main "$@"` 라인에서 실행이 시작된다.

## 9.3 최종 settings.json 구조

설치 완료 후 `~/.claude/settings.json`에 등록되는 훅:

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/squad-router.sh"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "zsh ~/.claude/hooks/subagent-chain.sh"
          }
        ]
      }
    ],
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

**`matcher: ""`의 의미**: 빈 문자열 = 모든 이벤트에 매칭. 특정 조건에서만 실행하려면 매처 패턴을 지정할 수 있다.

---

# 10장. Step 8 — 테스트와 CI/CD

> **이 단계의 목표**: 80개 키워드 × 8개 에이전트 = 조합 폭발. 키워드를 추가하거나 변경할 때 회귀(regression)를 방지하려면 자동화된 테스트가 필수다.

## 10.1 테스트 헬퍼 라이브러리 — helpers.sh

```bash
#!/bin/bash
# helpers.sh — Test assertion helpers for squad-router tests
# Usage: source tests/lib/helpers.sh

set -uo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROUTER="$REPO_ROOT/hooks/squad-router.sh"

# Parse --quiet flag
QUIET="${QUIET:-0}"
for arg in "$@"; do
  [ "$arg" = "--quiet" ] && QUIET=1
done

# run_router <prompt> [env_vars...]
# Sets: ROUTER_OUTPUT, ROUTER_EXIT
run_router() {
  local prompt="$1"
  shift
  local json
  json=$(jq -n --arg p "$prompt" '{"prompt":$p}')
  ROUTER_OUTPUT=$(echo "$json" | env "$@" bash "$ROUTER" 2>/dev/null) || true
  ROUTER_EXIT=$?
}

# run_router_raw <raw_stdin>
# Sets: ROUTER_OUTPUT, ROUTER_EXIT
run_router_raw() {
  local raw="$1"
  ROUTER_OUTPUT=$(echo "$raw" | bash "$ROUTER" 2>/dev/null) || true
  ROUTER_EXIT=$?
}

# extract_agent — parse agent name from router output
extract_agent() {
  [ -z "$ROUTER_OUTPUT" ] && echo "" && return
  echo "$ROUTER_OUTPUT" | sed -n 's/.*the \(squad-[a-z]*\) subagent.*/\1/p'
}

# assert_routes_to <prompt> <expected_agent>
assert_routes_to() {
  local prompt="$1" expected="$2"
  run_router "$prompt"
  local actual
  actual=$(extract_agent)
  if [ "$actual" = "$expected" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s → %s\n" "$prompt" "$expected"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m %s → got '%s', expected '%s'\n" "$prompt" "$actual" "$expected"
  fi
}

# assert_no_output <prompt> [env_vars...]
assert_no_output() {
  local prompt="$1"
  shift
  run_router "$prompt" "$@"
  if [ -z "$ROUTER_OUTPUT" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s → (skip)\n" "$prompt"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m %s → expected no output, got: %s\n" "$prompt" "$ROUTER_OUTPUT"
  fi
}

# assert_no_output_raw <raw_stdin>
assert_no_output_raw() {
  local raw="$1"
  run_router_raw "$raw"
  if [ -z "$ROUTER_OUTPUT" ]; then
    ((PASS++)) || true
    [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m (raw: %s) → (skip)\n" "${raw:0:40}"
  else
    ((FAIL++)) || true
    printf "  \033[31m✗\033[0m (raw) → expected no output, got: %s\n" "$ROUTER_OUTPUT"
  fi
}

# summary — print results and exit
summary() {
  echo ""
  if [ "$FAIL" -gt 0 ]; then
    printf "\033[31mFAILED: %d passed, %d failed, %d total\033[0m\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
    exit 1
  else
    printf "\033[32mPASSED: %d passed, 0 failed, %d total\033[0m\n" "$PASS" "$PASS"
    exit 0
  fi
}
```

### 핵심 함수 해설

**`run_router()`**: 프롬프트 문자열을 JSON으로 변환하고 라우터에 전달

```bash
json=$(jq -n --arg p "$prompt" '{"prompt":$p}')
ROUTER_OUTPUT=$(echo "$json" | env "$@" bash "$ROUTER" 2>/dev/null) || true
```

`env "$@"`를 사용하여 환경변수를 전달할 수 있다. 예: `run_router "보안 검사" "SQUAD_ROUTER=off"` → 환경변수 킬스위치 테스트

**`assert_routes_to()`**: 프롬프트가 예상 에이전트로 라우팅되는지 검증
**`assert_no_output()`**: 프롬프트가 스킵 조건에 해당하여 출력이 없는지 검증

## 10.2 라우터 키워드 테스트 — test-router.sh

```bash
#!/bin/bash
# test-router.sh — Squad Router keyword routing test suite
# Usage: bash tests/test-router.sh [--quiet]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/helpers.sh" "$@"

# Verify jq is available
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for tests"
  exit 1
fi

echo "Squad Router Test Suite"
echo "======================"

# ─── A. Skip Conditions ──────────────────────────────────
echo ""
echo "A. Skip Conditions"

assert_no_output "보안 검사해줘" "SQUAD_ROUTER=off"
assert_no_output ""
assert_no_output "/squad-review src/"
assert_no_output "/anything"
assert_no_output "review this code --no-route"
assert_no_output "debug this #direct"
assert_no_output "SECURITY CHECK --NO-ROUTE"
assert_no_output_raw "not valid json at all"
assert_no_output_raw "{}"

# ─── B. Conflict Resolution (Multi-word) ────────────────
echo ""
echo "B. Conflict Resolution (Multi-word patterns)"

# PR review vs PR write
assert_routes_to "pr 리뷰 해줘" "squad-review"
assert_routes_to "please do a pr review" "squad-review"
assert_routes_to "테스트 코드 리뷰 해줘" "squad-review"
assert_routes_to "pr 작성해줘" "squad-gitops"
assert_routes_to "pr 만들어줘" "squad-gitops"
assert_routes_to "pr 써줘" "squad-gitops"

# Security review vs general review
assert_routes_to "보안 리뷰 해줘" "squad-audit"
assert_routes_to "security review please" "squad-audit"
assert_routes_to "보안 검토 부탁" "squad-audit"

# Build error vs build check
assert_routes_to "빌드 에러 수정해줘" "squad-debug"
assert_routes_to "build error fix" "squad-debug"
assert_routes_to "빌드 확인해줘" "squad-qa"
assert_routes_to "빌드 돌려봐" "squad-qa"
assert_routes_to "build check please" "squad-qa"

# Code cleanup
assert_routes_to "코드 정리 해줘" "squad-refactor"
assert_routes_to "do a code cleanup" "squad-refactor"

# ─── C. General Keywords (per agent) ────────────────────
echo ""
echo "C. General Keywords"

# Priority 1: squad-audit
assert_routes_to "보안 점검해줘" "squad-audit"
assert_routes_to "check for security issues" "squad-audit"
assert_routes_to "취약점 분석해" "squad-audit"
assert_routes_to "run an audit" "squad-audit"
assert_routes_to "check for xss" "squad-audit"
assert_routes_to "csrf 방어 확인" "squad-audit"

# Priority 2: squad-debug
assert_routes_to "디버그 해줘" "squad-debug"
assert_routes_to "debug this function" "squad-debug"
assert_routes_to "에러 났어" "squad-debug"
assert_routes_to "there is an exception" "squad-debug"
assert_routes_to "stack trace 분석해" "squad-debug"
assert_routes_to "크래시 원인 찾아줘" "squad-debug"

# Priority 3: squad-plan
assert_routes_to "기획서 작성해줘" "squad-plan"
assert_routes_to "plan the feature" "squad-plan"
assert_routes_to "wireframe 그려줘" "squad-plan"
assert_routes_to "user story 작성" "squad-plan"

# Priority 4: squad-refactor
assert_routes_to "리팩토링 해줘" "squad-refactor"
assert_routes_to "refactor this module" "squad-refactor"
assert_routes_to "extract this function" "squad-refactor"

# Priority 5: squad-docs
assert_routes_to "문서화 해줘" "squad-docs"
assert_routes_to "update the readme" "squad-docs"
assert_routes_to "add jsdoc comments" "squad-docs"

# Priority 6: squad-gitops
assert_routes_to "커밋 메시지 작성해" "squad-gitops"
assert_routes_to "write a commit message" "squad-gitops"
assert_routes_to "generate changelog" "squad-gitops"

# Priority 7: squad-qa
assert_routes_to "테스트 작성해줘" "squad-qa"
assert_routes_to "run the tests" "squad-qa"
assert_routes_to "lint check 해줘" "squad-qa"

# Priority 8: squad-review
assert_routes_to "리뷰 해줘" "squad-review"
assert_routes_to "review my code" "squad-review"
assert_routes_to "diff 봐줘" "squad-review"

# ─── D. Priority Ordering ───────────────────────────────
echo ""
echo "D. Priority Ordering"

assert_routes_to "review the security code" "squad-audit"
assert_routes_to "debug this test failure" "squad-debug"
assert_routes_to "refactor the test helper" "squad-refactor"
assert_routes_to "document the test setup" "squad-docs"

# ─── E. Edge Cases ──────────────────────────────────────
echo ""
echo "E. Edge Cases"

# "plan " requires trailing space — "planet" should NOT match
assert_no_output "planet earth is beautiful"
# But "plan the" should match (contains "plan ")
assert_routes_to "plan the architecture" "squad-plan"
# Case insensitive
assert_routes_to "SECURITY AUDIT NOW" "squad-audit"
# No keywords
assert_no_output "hello how are you"
assert_no_output "deploy to production"
assert_no_output "open the file"
# Long prompt with keyword buried
assert_routes_to "I have this really long description of a problem and somewhere in the middle there is a bug that needs fixing" "squad-debug"

# ─── Summary ────────────────────────────────────────────
summary
```

### 테스트 구조 해설

5개 카테고리로 체계적으로 검증한다:

| 카테고리 | 검증 내용 | 테스트 수 |
|---------|----------|----------|
| A. Skip Conditions | 환경변수, 슬래시 커맨드, opt-out, 잘못된 JSON | 9 |
| B. Conflict Resolution | 다단어 충돌 패턴 | 15 |
| C. General Keywords | 에이전트별 키워드 매칭 | 24 |
| D. Priority Ordering | 여러 키워드가 겹칠 때 우선순위 | 4 |
| E. Edge Cases | "planet" 오탐 방지, 대소문자, 긴 프롬프트 | 7 |

**D. Priority Ordering이 가장 중요하다:**

```bash
assert_routes_to "review the security code" "squad-audit"
# "review" → squad-review (순위 8)
# "security" → squad-audit (순위 1)
# → squad-audit이 이겨야 한다 (first-match-wins)
```

## 10.3 파일 무결성 테스트 — test-files.sh

```bash
#!/bin/bash
# test-files.sh — Validate agent/command file integrity
# Usage: bash tests/test-files.sh [--quiet]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
QUIET=0
for arg in "$@"; do
  [ "$arg" = "--quiet" ] && QUIET=1
done

pass() {
  ((PASS++)) || true
  [ "$QUIET" != "1" ] && printf "  \033[32m✓\033[0m %s\n" "$1"
}

fail() {
  ((FAIL++)) || true
  printf "  \033[31m✗\033[0m %s\n" "$1"
}

echo "Squad File Integrity Tests"
echo "=========================="

# ─── 1. Extract routed agents from squad-router.sh ──────
echo ""
echo "1. Router-to-file consistency"

ROUTED_AGENTS=$(grep -o 'AGENT="squad-[a-z]*"' "$REPO_ROOT/hooks/squad-router.sh" | \
  sed 's/AGENT="//;s/"//' | sort -u)

for agent in $ROUTED_AGENTS; do
  # Check agent definition exists
  if [ -f "$REPO_ROOT/agents/${agent}.md" ]; then
    pass "$agent → agents/${agent}.md exists"
  else
    fail "$agent → agents/${agent}.md MISSING"
  fi

  # Check command definition exists
  if [ -f "$REPO_ROOT/commands/${agent}.md" ]; then
    pass "$agent → commands/${agent}.md exists"
  else
    fail "$agent → commands/${agent}.md MISSING"
  fi
done

# ─── 2. Agent frontmatter validation ───────────────────
echo ""
echo "2. Agent frontmatter"

for f in "$REPO_ROOT"/agents/squad-*.md; do
  [ -f "$f" ] || continue
  local_name=$(basename "$f" .md)

  # Check starts with ---
  if head -1 "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter open"
  else
    fail "$local_name: missing opening ---"
    continue
  fi

  # Check has closing ---
  if sed -n '2,$p' "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter close"
  else
    fail "$local_name: missing closing ---"
    continue
  fi

  # Check name field matches filename
  fm_name=$(awk '/^---$/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$f")
  if [ "$fm_name" = "$local_name" ]; then
    pass "$local_name: name field matches"
  else
    fail "$local_name: name='$fm_name' expected='$local_name'"
  fi

  # Check has model field
  if sed -n '/^---$/,/^---$/p' "$f" | grep -q '^model:'; then
    pass "$local_name: has model field"
  else
    fail "$local_name: missing model field"
  fi

  # Check has tools field
  if sed -n '/^---$/,/^---$/p' "$f" | grep -q '^tools:'; then
    pass "$local_name: has tools field"
  else
    fail "$local_name: missing tools field"
  fi
done

# ─── 3. Command frontmatter validation ─────────────────
echo ""
echo "3. Command frontmatter"

for f in "$REPO_ROOT"/commands/squad*.md; do
  [ -f "$f" ] || continue
  local_name=$(basename "$f" .md)

  if head -1 "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter open"
  else
    fail "$local_name: missing opening ---"
  fi

  if sed -n '2,$p' "$f" | grep -q '^---$'; then
    pass "$local_name: frontmatter close"
  else
    fail "$local_name: missing closing ---"
  fi
done

# ─── 4. install.sh agent list consistency ───────────────
echo ""
echo "4. install.sh consistency"

INSTALL_AGENTS=$(grep -A1 'SQUAD_AGENTS=' "$REPO_ROOT/install.sh" | \
  grep -o 'squad-[a-z]*' | sort -u)

for agent in $INSTALL_AGENTS; do
  if [ -f "$REPO_ROOT/agents/${agent}.md" ]; then
    pass "install.sh: $agent has agent file"
  else
    fail "install.sh: $agent listed but agents/${agent}.md missing"
  fi
done

# ─── Summary ────────────────────────────────────────────
echo ""
if [ "$FAIL" -gt 0 ]; then
  printf "\033[31mFAILED: %d passed, %d failed, %d total\033[0m\n" "$PASS" "$FAIL" "$((PASS+FAIL))"
  exit 1
else
  printf "\033[32mPASSED: %d passed, 0 failed, %d total\033[0m\n" "$PASS" "$PASS"
  exit 0
fi
```

### 무결성 테스트 해설

이 테스트는 "시스템이 일관되는가?"를 검증한다:

1. **라우터-파일 일관성**: `squad-router.sh`에서 참조하는 모든 에이전트에 대해 `.md` 파일이 존재하는가?
2. **Frontmatter 유효성**: `name` 필드가 파일명과 일치하는가? `model`, `tools` 필드가 있는가?
3. **커맨드 Frontmatter**: 모든 커맨드 파일의 Frontmatter가 올바른가?
4. **install.sh 일관성**: `install.sh`의 에이전트 목록에 있는 모든 에이전트에 대해 파일이 존재하는가?

## 10.4 CI/CD 파이프라인

### pre-commit 훅

개발자가 커밋할 때마다 자동으로 테스트가 실행된다:

```bash
# 등록
bash install.sh --dev

# .git/hooks/pre-commit 에 생성됨:
#!/bin/bash
set -euo pipefail
REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "Running squad-router tests..."
bash "$REPO_ROOT/tests/test-router.sh" --quiet || exit 1
bash "$REPO_ROOT/tests/test-files.sh" --quiet || exit 1
echo "All tests passed."
```

### 통합 실행

```bash
bash tests/run-all.sh
```

---

# 11장. 커스터마이징 가이드

## 11.1 새 에이전트 추가하기

새 에이전트 `squad-perf` (성능 프로파일링)를 추가한다고 하자:

**체크리스트:**

1. `agents/squad-perf.md` 생성 (Frontmatter + 시스템 프롬프트)
2. `commands/squad-perf.md` 생성 (슬래시 커맨드 정의)
3. `hooks/squad-router.sh` Phase 3에 키워드 추가:
   ```bash
   *"성능"*|*"performance"*|*"프로파일"*|*"profil"*|*"벤치마크"*|*"benchmark"*)
     AGENT="squad-perf" ;;
   ```
4. `install.sh`의 `SQUAD_AGENTS` 배열에 `squad-perf` 추가
5. `tests/test-router.sh`에 테스트 케이스 추가:
   ```bash
   assert_routes_to "성능 분석해줘" "squad-perf"
   assert_routes_to "run benchmark" "squad-perf"
   ```
6. 테스트 실행: `bash tests/run-all.sh`

## 11.2 키워드 추가/변경

키워드를 추가할 때는 **오탐 평가 체크리스트**를 거친다:

| 질문 | 통과 기준 |
|------|----------|
| 이 단어가 일상 대화에서 다른 의미로 쓰이는가? | "아니오"여야 통과 |
| 3글자 이하인가? | "아니오"여야 통과 (짧은 단어는 부분 매칭 위험) |
| 다른 에이전트의 키워드와 겹치는가? | 겹치면 Phase 2에 충돌 해결 패턴 추가 |
| "planet" 같은 부분 매칭 문제가 있는가? | 뒤에 공백 추가 (`*"plan "*`) |

**반드시 테스트를 추가한다.** 키워드 추가 없이 테스트만 돌려보면 기존 키워드가 깨졌는지 즉시 확인할 수 있다.

## 11.3 알림 커스터마이징

### Slack 웹훅으로 교체

`subagent-chain.sh`의 `notify()` 함수를 수정:

```bash
notify() {
  local title="$1" body="$2"
  curl -sX POST "https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
    -H 'Content-type: application/json' \
    -d "{\"text\": \"${title}: ${body}\"}" &
}
```

### 특정 에이전트만 알림

```bash
# squad-audit과 squad-debug만 알림
case "$AGENT_NAME" in
  "squad-audit"|"squad-debug") notify ... ;;
  *) ;; # 나머지는 무시
esac
```

### 사운드 변경 (macOS)

```bash
# 사용 가능한 사운드 목록
ls /System/Library/Sounds/

# play_sound()에서 변경
afplay "/System/Library/Sounds/Submarine.aiff" 2>/dev/null &
```

## 11.4 파이프라인 변경

`subagent-chain.sh`의 NEXT 변수를 수정하여 체이닝 순서를 바꿀 수 있다:

```bash
case "$AGENT_NAME" in
  "squad-review")
    NEXT="→ /squad-qa (테스트 먼저, 그 다음 리팩토링)"  # 순서 변경
    ;;
esac
```

## 11.5 모델 라우팅 변경

**개별 에이전트**: Frontmatter의 `model` 필드 수정

```yaml
model: sonnet  # opus에서 sonnet으로 변경 (비용 절감)
```

**전역 오버라이드**: 환경변수 설정

```bash
export CLAUDE_CODE_SUBAGENT_MODEL=sonnet  # 모든 서브에이전트를 sonnet으로
```

---

# 부록

## A. 전체 키워드 레퍼런스

### squad-audit (우선순위 1)
| 한국어 | 영어 |
|--------|------|
| 보안 | security |
| 취약점 | vulnerab* |
| — | audit |
| — | owasp |
| 시크릿 | secret |
| 인젝션 | injection |
| — | xss |
| — | csrf |

### squad-debug (우선순위 2)
| 한국어 | 영어 |
|--------|------|
| 디버그 | debug |
| 에러 | error |
| 버그 | bug |
| 오류 | — |
| 크래시 | crash |
| — | stack trace |
| — | traceback |
| — | exception |

### squad-plan (우선순위 3)
| 한국어 | 영어 |
|--------|------|
| 기획 | plan (뒤 공백) |
| 설계해 | — |
| 와이어프레임 | wireframe |
| 유저스토리 | user story |
| 브레인스토밍 | brainstorm |
| 스펙 | spec |
| 요구사항 | — |
| 구현 계획 | — |

### squad-refactor (우선순위 4)
| 한국어 | 영어 |
|--------|------|
| 리팩토링 | refactor |
| 리팩터 | — |
| 클린업 | cleanup / clean up |
| 추출 | extract |
| 중복 제거 | — |
| 코드 개선 | — |
| 함수 분리 | — |
| 컴포넌트 분리 | — |

### squad-docs (우선순위 5)
| 한국어 | 영어 |
|--------|------|
| 문서화 | document |
| 문서 | — |
| 리드미 | readme |
| — | jsdoc |
| — | tsdoc |
| 주석 | comment |

### squad-gitops (우선순위 6)
| 한국어 | 영어 |
|--------|------|
| 커밋 | commit |
| 체인지로그 | changelog |
| 릴리즈 노트 | release note |
| — | conventional |

### squad-qa (우선순위 7)
| 한국어 | 영어 |
|--------|------|
| 테스트 | test |
| — | qa |
| 검증 | — |
| 린트 | lint |
| 타입체크 | type check |
| 리그레션 | regression |

### squad-review (우선순위 8)
| 한국어 | 영어 |
|--------|------|
| 리뷰 | review |
| 코드 검토 | — |
| 검토해 | — |
| diff 봐 | — |

### 충돌 해결 패턴 (Phase 2)

| 패턴 | 라우팅 결과 |
|------|-----------|
| PR 리뷰 / PR review | squad-review |
| 테스트 코드 리뷰 | squad-review |
| PR 작성 / PR 만들 / PR 써 | squad-gitops |
| 보안 리뷰 / 보안 검토 / security review | squad-audit |
| 에러 테스트 / 빌드 에러 / build error | squad-debug |
| 빌드 확인 / 빌드 돌 / build check | squad-qa |
| 코드 정리 / code cleanup | squad-refactor |

## B. Frontmatter 전체 필드 레퍼런스

| 필드 | 필수 | 기본값 | 설명 |
|------|------|--------|------|
| `name` | 예 | — | 에이전트 ID (`Agent(subagent_type="이 값")`) |
| `description` | 예 | — | 자동 위임 트리거. `PROACTIVELY` 포함 시 자동 호출 |
| `tools` | 아니오 | 상속 | 쉼표 구분 허용 도구. `Task(squad-name)` 지원 |
| `model` | 아니오 | inherit | `haiku` / `sonnet` / `opus` / `inherit` |
| `maxTurns` | 아니오 | — | 최대 턴 수 (무한 루프 방지) |
| `permissionMode` | 아니오 | — | `plan` / `acceptEdits` / `bypassPermissions` |
| `memory` | 아니오 | — | `user` / `project` / `local` |
| `background` | 아니오 | false | 백그라운드 실행 |
| `skills` | 아니오 | — | 사전 로드할 스킬 목록 |
| `mcpServers` | 아니오 | — | 에이전트 전용 MCP 서버 |
| `hooks` | 아니오 | — | 에이전트 전용 훅 |

## C. settings.json 전체 예시

```jsonc
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/squad-router.sh"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "zsh ~/.claude/hooks/subagent-chain.sh"
          }
        ]
      }
    ],
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

## D. 트러블슈팅 가이드

| 문제 | 원인 | 해결 |
|------|------|------|
| 에이전트가 목록에 없음 | 파일 위치 또는 Frontmatter 오류 | `/agents` 실행. `---`로 시작/끝나는지 확인 |
| YAML 파싱 에러 | `description`에 `:` 포함 시 | `>` 블록 스칼라 사용, 탭 대신 공백 |
| 무한 실행 | `maxTurns` 미설정 | `maxTurns: 15` 추가 |
| 라우터가 동작 안 함 | settings.json 등록 누락 | `bash install.sh` 재실행 또는 수동 등록 |
| jq 관련 에러 | jq 미설치 | `brew install jq` 또는 `apt install jq` |
| 잘못된 에이전트로 라우팅 | 키워드 충돌 | Phase 2에 충돌 해결 패턴 추가 |
| 알림이 안 옴 | TUI 앱이므로 echo 불가 | OS 알림 설정 확인 (시스템 환경설정) |
| 디버그 모드 | 훅 실행 문제 추적 | `claude --debug "api,hooks"` |

## E. 참고 자료

- [Claude Code Sub-agents (공식 문서)](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Code Hooks (공식 문서)](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Agent SDK](https://docs.anthropic.com/en/docs/agents/agent-sdk)

---

> **강좌 끝.** 이 문서를 따라 8개 전문 에이전트, 키워드 자동 라우팅, 파이프라인 체이닝, 원클릭 설치까지 갖춘 서브에이전트 시스템을 구축할 수 있다.
