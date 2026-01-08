# AI 코드 검사 자동화

GitHub Actions로 PR에 AI 코드 검사를 자동화합니다.

## 이 시스템이 하는 일

1. PR 생성 시 `🚧 not-ready` 라벨을 자동 추가
2. 라벨이 있으면 모든 검사를 스킵 (비용 절감)
3. 라벨을 제거하면 테스트 + AI 검사 1회 자동 실행
4. PR이 열린 상태에서 푸시하면 테스트 + AI 검사 1회 자동 실행 (라벨 없을 때만)
5. **푸시하면 이전 통과 기록은 전부 무효화** (새 커밋 기준으로 다시 시작)
6. 같은 커밋에서 N개의 AI 검사가 통과하면 머지 가능 (또는 사람이 Approve)

---

## 설정 가이드

### 1단계: 워크플로우 파일 추가

이 레포의 `.github/workflows/` 폴더에 있는 파일들을 본인 레포의 같은 경로에 복사합니다.

| 파일 | 필수 | 설명 |
|------|------|------|
| `pr-review.yml` | O | PR 라벨 관리, 테스트, AI 검사, 머지 판정 |
| `approval-override.yml` | X | Approve 시 자동 override |

### 2단계: GitHub 저장소 설정

GitHub 웹에서 본인 레포의 Settings로 이동합니다.

#### (1) Workflow 권한 설정

**경로**: Settings → Actions → General → Workflow permissions

다음 두 항목을 설정:
- **Read and write permissions** 선택 (기본값이 Read-only라 변경 필수)
- **Allow GitHub Actions to create and approve pull requests** 체크

#### (2) Branch Protection 설정

**경로**: Settings → Branches → Add branch protection rule

설정 내용:
- **Branch name pattern**: `main` (또는 본인의 기본 브랜치명)
- **Require status checks to pass before merging** 체크
- **Status checks that are required** 에서 `merge-gate` 검색해서 추가

> 참고: `merge-gate`는 PR을 한 번 이상 만들어야 검색에 나타납니다.

#### (3) 설정 변경 (선택)

`pr-review.yml`의 `env` 섹션에서 직접 수정:
- `REQUIRED_COUNT`: 머지에 필요한 AI 검사 횟수
- `COOLDOWN_MINUTES`: 자동 검사 최소 간격 (분)
- `NOT_READY_LABEL`: 리뷰 스킵용 라벨

### 3단계: AI API 설정

현재 Amazon Bedrock API를 사용합니다.

1. AWS에서 Bedrock 모델 접근 권한 활성화
2. GitHub Secrets에 `BEDROCK_API_KEY` 추가
3. `pr-review.yml`의 `AI_MODEL` 환경변수에서 모델 선택:
   - `us.amazon.nova-micro-v1:0` (기본값, 가장 저렴)
   - `anthropic.claude-4-sonnet-20250514-v1:0`
   - 등

---

## 사용 방법

### PR 작업 흐름

```
1. PR 생성
   └─ 🚧 not-ready 라벨 자동 추가됨
   └─ 안내 코멘트가 달림
   └─ 이 상태에서는 push해도 검사 안 함

2. 라벨 제거 (검사 시작)
   └─ 테스트 + AI 검사 1회 자동 실행

3. PR에 푸시 (라벨 없는 상태에서)
   └─ 테스트 + AI 검사 1회 자동 실행
   └─ ⚠️ 이전 커밋의 통과 기록은 무효화됨 (새 커밋 기준으로 다시 시작)
   └─ PR이 없는 브랜치에 푸시하면 검사 안 함

4. 추가 검사 필요 시
   └─ Actions에서 수동 실행 (같은 커밋에서 N개 채우기)

5. 머지
   └─ 같은 커밋에서 N개 검사 전부 통과: merge-gate ✅
   └─ 실패가 있으면: 사람 Approve로 override 가능
```

### 수동으로 검사 실행하기

**GitHub 웹**:
1. Actions 탭 클릭
2. 왼쪽에서 "AI Code Review" 선택
3. "Run workflow" 클릭
4. PR 번호 입력 후 실행

**CLI**:
```bash
gh workflow run pr-review.yml -f pr_number=123
```

---

## Status Checks 설명

PR의 Checks 탭에서 다음 status들을 볼 수 있습니다:

| Status | 의미 |
|--------|------|
| `ai-review-1` | 첫 번째 AI 검사 결과 |
| `ai-review-2` | 두 번째 AI 검사 결과 |
| `ai-review-N` | N번째 AI 검사 결과 |
| `merge-gate` | **종합 판정** - 이것만 통과하면 머지 가능 |

`merge-gate` 상태:
- `pending`: 아직 N개 검사 미완료
- `success`: 머지 가능
- `failure`: AI 검사 실패 있음 - Approve 필요

---

## 세부 동작 규칙

자세한 요구조건 정의는 [SPEC.md](./SPEC.md)를 참고하세요.

주요 규칙:
- 테스트 통과해야 AI 검사 실행
- 푸시하면 이전 검사 기록 전부 무효화 (새 커밋 기준)
- N개 슬롯이 다 차면 추가 검사 불가, 재시도는 푸시로
- 쿨다운은 자동 실행에만 적용, 수동 실행은 무시
- 1개라도 실패 있으면 사람 Approve 필요

---

## 문제가 생겼을 때

[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)에서 자주 발생하는 문제와 해결 방법, 워크플로우 수정 시 주의사항을 확인하세요.
