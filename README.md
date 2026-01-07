# AI 코드 검사 자동화

GitHub Actions로 PR에 AI 코드 검사를 자동화합니다.

## 이 시스템이 하는 일

1. PR 생성 시 `🚧 not-ready` 라벨을 자동 추가
2. 라벨이 있으면 검사를 스킵 (비용 절감)
3. 라벨을 제거하면 테스트 → AI 검사 실행
4. N개의 AI 검사가 통과하면 머지 가능 (또는 사람이 Approve)

---

## 설정 가이드

### 1단계: 워크플로우 파일 추가

이 레포의 `.github/workflows/` 폴더에 있는 파일들을 본인 레포의 같은 경로에 복사합니다.

| 파일 | 필수 | 설명 |
|------|------|------|
| `ai-review.yml` | O | PR 라벨 관리, 테스트, AI 검사, 머지 판정 |
| `approval-override.yml` | X | Approve 시 자동 override |
| `test.yml` | X | PR/push 시 테스트만 실행 (참고용) |

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

#### (3) 검사 횟수 설정 (선택)

**경로**: Settings → Secrets and variables → Actions → Variables 탭 → New repository variable

| Name | Value | 설명 |
|------|-------|------|
| `AI_REVIEW_REQUIRED_COUNT` | 원하는 숫자 | 머지에 필요한 AI 검사 횟수 (미설정 시 기본값 3) |

### 3단계: AI 검사 로직 연결

`ai-review.yml` 파일에서 `Run AI Review` 단계를 찾아 실제 AI API 호출로 교체합니다.

현재는 테스트용으로 joke API를 사용해 랜덤하게 pass/fail을 반환합니다.

```yaml
- name: Run AI Review
  id: ai-check
  run: |
    # 여기에 실제 AI API 호출 코드 작성
    # 결과를 RESULT 변수에 "pass" 또는 "fail"로 저장
    echo "result=$RESULT" >> $GITHUB_OUTPUT
```

---

## 사용 방법

### PR 작업 흐름

```
1. PR 생성
   └─ 🚧 not-ready 라벨 자동 추가됨
   └─ 안내 코멘트가 달림
   └─ 이 상태에서는 push해도 검사 안 함

2. 라벨 제거 (검사 시작)
   └─ 테스트 실행
   └─ 테스트 통과 시 AI 검사 1회 실행

3. 추가 검사 필요 시
   └─ push하면 자동 실행 (쿨다운 5분)
   └─ 또는 Actions에서 수동 실행

4. 머지
   └─ N개 검사 전부 통과: merge-gate ✅
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
gh workflow run ai-review.yml -f pr_number=123
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

## 설정 커스터마이징

`ai-review.yml` 상단의 `env` 섹션에서 수정:

```yaml
env:
  REQUIRED_COUNT: ${{ vars.AI_REVIEW_REQUIRED_COUNT || 3 }}  # 필요 검사 횟수
  COOLDOWN_MINUTES: 5                                         # 자동 검사 최소 간격 (분)
  NOT_READY_LABEL: "🚧 not-ready"                            # 스킵용 라벨 이름
```

---

## 문제가 생겼을 때

[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)에서 자주 발생하는 문제와 해결 방법, 워크플로우 수정 시 주의사항을 확인하세요.
