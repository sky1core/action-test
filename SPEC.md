# AI 코드 리뷰 시스템 요구조건 정의서

## 용어 정의

| 용어 | 정의 |
|------|------|
| 커밋 | Git commit SHA. 푸시할 때마다 새로운 SHA가 생성됨 |
| 슬롯 | AI 리뷰 결과를 저장하는 칸 (`ai-review-1`, `ai-review-2`, ...) |
| N | 머지에 필요한 리뷰 횟수 (기본값 2, 변수로 설정 가능) |
| 라벨 | `🚧 WIP` 라벨. 리뷰 스킵용 |

---

## 기본 흐름

### Q: PR을 생성하면 어떻게 되나?
- `🚧 WIP` 라벨이 자동으로 추가됨
- 안내 코멘트가 달림
- `PR Review Status` = pending 상태

### Q: 라벨이 있으면 어떻게 되나?
- 모든 리뷰(단위테스트, AI 리뷰)가 스킵됨
- 푸시해도 리뷰 안 함

### Q: 라벨을 제거하면 어떻게 되나?
- 단위테스트 실행 → 통과하면 AI 리뷰 1회 자동 실행

### Q: PR에 푸시하면 어떻게 되나?
- 라벨 없으면: 단위테스트 실행 → 통과하면 AI 리뷰 1회 자동 실행
- 라벨 있으면: 아무것도 안 함
- **중요: 푸시하면 새 커밋(SHA)이 되므로 이전 리뷰 기록은 전부 무효화됨**

### Q: PR이 없는 브랜치에 푸시하면?
- 리뷰 안 함. PR이 열린 상태에서만 리뷰가 트리거됨.

---

## 단위테스트

### Q: 단위테스트와 AI 리뷰의 관계는?
- 별개의 작업임
- 각각 독립적으로 수동 실행 가능
- 자동 실행 시에만 단위테스트 → AI 리뷰 순서로 연결됨

### Q: 자동 실행 시 단위테스트가 실패하면?
- AI 리뷰 실행 안 함
- 이유: AI 리뷰는 비용이 드는 작업. 단위테스트도 못 통과하는 코드에 AI 리뷰 돌릴 이유 없음.

### Q: 단위테스트는 언제 실행되나?
- 자동: 라벨 제거 시, PR에 푸시 시 (라벨 없을 때)
- 수동: 단위테스트 워크플로우에서 PR 번호 입력

### Q: AI 리뷰는 언제 실행되나?
- 자동: 단위테스트 통과 후 1회
- 수동: AI 리뷰 워크플로우에서 PR 번호 입력 (단위테스트 스킵)

### Q: 이전 댓글은 어떻게 되나?
- 푸시 후 새 단위테스트/AI 리뷰 실행 시, 이전 댓글은 접힘 처리됨
- 접힌 댓글은 `<details>` 태그로 감싸져 펼쳐서 볼 수 있음
- 이유: PR 댓글이 쌓이면 가독성이 떨어지므로

---

## 슬롯 시스템

### Q: 슬롯이 뭔가?
- AI 리뷰 결과를 저장하는 칸
- `ai-review-1`, `ai-review-2`, ... `ai-review-N` 형태
- 각 슬롯은 pass 또는 fail 상태를 가짐

### Q: 슬롯은 어떻게 채워지나?
- 리뷰가 실행될 때마다 빈 슬롯 중 가장 낮은 번호에 결과 저장
- 예: 1번 슬롯이 비어있으면 1번에, 1번이 차있고 2번이 비어있으면 2번에

### Q: N개 슬롯이 다 차면 어떻게 되나?
- 추가 리뷰 불가
- 재시도하려면 푸시해서 새 커밋으로 만들어야 함 (이전 기록 무효화)

### Q: 슬롯은 커밋마다 별도인가?
- 그렇다. 각 커밋(SHA)마다 별도의 슬롯이 있음
- 푸시하면 새 커밋이 되므로 슬롯이 전부 비어있는 상태로 시작

---

## 머지 조건

### Q: 머지하려면 어떤 조건이 필요한가?
- **방법 1**: 단위테스트 통과 + 같은 커밋에서 N개 AI 리뷰가 전부 통과 → `PR Review Status` = success
- **방법 2**: 사람이 Approve → `PR Review Status` = success (override)

### Q: 단위테스트 없이 AI 리뷰만 통과하면?
- `PR Review Status` = failure
- 사람 Approve 필요

### Q: N개 중 일부만 통과하면?
- 예: 3개 중 2개 통과, 1개 실패
- `PR Review Status` = failure
- 사람 Approve 필요

### Q: 실패가 하나라도 있으면 자동 머지 불가?
- 그렇다. 1개라도 실패가 있으면 `PR Review Status` = failure
- 사람이 Approve해야 override됨

### Q: pending 슬롯이 있으면 PR Review Status는?
- N개가 채워지기 전: `PR Review Status` = pending (추가 리뷰 필요)
- N개가 채워졌는데 pending 포함: `PR Review Status` = pending (리뷰 진행 중)
- N개가 채워지고 pending 없음: 전부 통과면 success, 실패 있으면 failure
- **pending은 "아직 결과 없음"이므로 success로 판정 불가**

---

## 수동 실행 (workflow_dispatch)

### Q: 수동 실행 가능한 워크플로우는?
- **단위테스트**: PR 브랜치의 단위테스트만 실행
- **AI 리뷰**: PR 브랜치의 코드 변경사항 리뷰 (단위테스트 스킵)

### Q: AI 리뷰 수동 실행은 언제 쓰나?
- 라벨 제거/푸시로 1회 자동 실행 후, 추가 리뷰가 필요할 때
- 같은 커밋에서 N개를 채우려면 수동 실행 필요

### Q: 수동 실행은 라벨을 체크하나?
- 아니오. 수동 실행은 라벨 상태 무시하고 실행됨
- 이유: 수동 실행은 명시적 의도가 있으므로

### Q: 수동 실행은 쿨다운이 적용되나?
- 아니오. 쿨다운은 자동 실행에만 적용됨

---

## 쿨다운

### Q: 쿨다운이 뭔가?
- 자동 실행 전 마지막 워크플로우 실행 이후 최소 대기 간격
- 기본값 20분
- 워크플로우 전체에 하나의 쿨다운 적용 (단위테스트 + AI 리뷰 통합)

### Q: 쿨다운의 목적은?
- 연속 푸시로 인한 리소스 낭비 방지

### Q: 쿨다운은 언제 적용되나?
- 자동 실행(라벨 제거, 푸시)에만 적용
- 수동 실행(workflow_dispatch)은 쿨다운 무시
- 쿨다운은 브랜치 기준으로 이전 워크플로우 실행 시간 확인

### Q: 쿨다운 중에 실행하고 싶으면?
- 수동 실행(workflow_dispatch) 사용

---

## 라벨 동작

### Q: 라벨을 제거했다가 다시 추가하면?
- 라벨이 다시 존재하므로 이후 이벤트(푸시)에서 리뷰 스킵
- 이미 진행 중인 리뷰는 계속 실행됨 (중단되지 않음)

### Q: 다시 추가한 라벨을 또 제거하면?
- 리뷰 실행됨. 라벨 제거 시마다 리뷰가 1회 실행됨.
- 즉, 라벨 추가/제거를 반복해도 "제거할 때마다" 리뷰 트리거됨

### Q: 라벨은 누가 추가/제거하나?
- PR 생성 시 시스템이 자동 추가
- 제거는 사람이 수동으로

---

## Approve Override

### Q: Approve 하는 방법은?
1. PR 페이지에서 "Files changed" 탭 클릭
2. 오른쪽 위 "Review changes" 버튼 클릭
3. "Approve" 선택 후 "Submit review"

### Q: Approve의 역할은?
- Approve = 머지 허용
- Approve가 있으면 PR Review Status가 즉시 success가 됨

### Q: Approve하면 어떻게 되나?
- `PR Review Status`가 즉시 success로 override됨 (pending이든 failure든)
- `PR Review Status`가 이미 success면 변화 없음

### Q: Approve 있는 상태에서 푸시하면?
- 새 SHA에서 리뷰가 다시 시작됨
- Branch protection 설정 시 기존 Approve가 자동 dismiss됨
- 다시 리뷰를 통과하거나 새로 Approve 받아야 함

### Q: 리뷰를 안 받고 Approve만으로 머지할 수 있나?
- 가능. Approve가 있으면 리뷰 결과와 무관하게 머지 가능

### Q: Approve가 취소(dismiss)되면?
- 다른 Approve가 남아있으면: 변화 없음
- Approve가 0개가 되면: PR Review Status가 다시 failure로 복원됨
- 단, 리뷰 통과로 success가 된 경우는 복원 안 함 (override로 success된 경우만 복원)

---

## 상수

| 항목 | 값 | 설명 |
|------|-----|------|
| `REQUIRED_COUNT` | 2 | 머지에 필요한 AI 리뷰 횟수 |
| `COOLDOWN_MINUTES` | 20 | 자동 리뷰 최소 간격 (분) |
| `NOT_READY_LABEL` | `🚧 WIP` | 리뷰 스킵용 라벨 |
| `REVIEW_PREFIX` | `AI Review` | AI 리뷰 코멘트 제목 접두사 |
| `TEST_PREFIX` | `Unit Test` | 단위테스트 코멘트 제목 접두사 |

변경하려면 yml 파일을 수정하고 PR을 올려야 합니다. (리뷰 필요)

---

## 커스터마이징 (yml 직접 수정)

### Q: 리뷰 횟수나 쿨다운을 바꾸고 싶으면?
- `pr-review.yml`의 `REQUIRED_COUNT`, `COOLDOWN_MINUTES` 값 수정
- `pr-review-approval.yml`의 `REQUIRED_COUNT`도 함께 수정

### Q: 라벨 이름을 바꾸고 싶으면?
- `pr-review.yml`의 `NOT_READY_LABEL` 값 수정

### Q: 단위테스트 명령어를 바꾸고 싶으면?
- `pr-review.yml`의 `Run unit tests` 단계 수정
- 현재: `uv run pytest tests/ -v`
- 프로젝트에 맞게 변경 필요

### Q: 대상 브랜치를 바꾸고 싶으면?
- `pr-review.yml`의 `branches: [main, master]` 수정
- `pr-review-approval.yml`의 job if 조건도 함께 수정 필요
- 예: `branches: [develop]`

### Q: 프로젝트별 리뷰 규칙을 추가하고 싶으면?
- `pr-review.yml`의 `CUSTOM_REVIEW_RULES` 환경변수에 규칙 작성
- 내용은 AI 리뷰 프롬프트에 자동 포함됨
- 예: 성능 우선 프로젝트는 "O(n²) 이상은 Warning", 보안 프로젝트는 "외부 입력 검증 필수" 등
- 비워두면 기본 규칙만 적용
- ⚠️ 규칙 변경은 워크플로우 파일 수정이므로 AI 리뷰에서 🔴 Critical로 분류됨

---

## Branch Protection 설정

### Q: Branch Protection을 설정 안 하면?
- PR Review Status 결과와 무관하게 머지 가능
- 푸시해도 Approve가 유지됨
- 리뷰가 의미 없어짐
- **반드시 설정해야 함**

### Q: 어떻게 설정하나?
Settings → Branches → Add branch protection rule

1. **Branch name pattern**: `main` (또는 본인 기본 브랜치)

2. **Require a pull request before merging** 체크
   - "Dismiss stale pull request approvals when new commits are pushed" 체크

3. **Require status checks to pass before merging** 체크
   - "Status checks that are required"에서 `PR Review Status` 검색해서 추가

4. **Save changes** 클릭

---

## AWS Bedrock API 키 설정

### Q: API 키는 어디서 발급하나?
Bedrock 콘솔 → API keys → Create long-term key

https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1#/api-keys/long-term/create

- 최대 30일 유효
- IAM 설정 불필요
- 테스트용으로 적합

### Q: GitHub Secrets에 어떻게 추가하나?
Repository → Settings → Secrets and variables → Actions → New repository secret

추가할 시크릿:
- `BEDROCK_API_KEY`: 발급받은 API 키

---

## 게이밍 방지

### Q: 푸시를 반복해서 운 좋게 통과할 수 있나?
- 불가능
- 푸시하면 새 커밋이 되고, 이전 통과 기록도 무효화됨
- 새 커밋에서 다시 N개를 전부 통과해야 함

### Q: 수동 실행을 반복해서 운 좋게 통과할 수 있나?
- N개 슬롯이 다 차면 추가 리뷰 불가
- 재시도하려면 푸시해야 하고, 푸시하면 이전 기록 무효화
- 따라서 같은 커밋에서 N번의 기회만 있음

---

## 동시 실행

### Q: 같은 PR에서 여러 리뷰가 동시에 실행되면?
- 동시 실행 안 됨. 순차 처리됨.
- concurrency 설정으로 같은 PR에 대한 워크플로우는 큐에 쌓여서 순서대로 실행
- 슬롯 충돌 없음

---

## 에러 처리

### Q: AI API 호출이 실패하면?
- 해당 슬롯이 pending 상태로 남음
- pending 상태의 슬롯은 재사용 불가 (채워진 것으로 취급)
- PR Review Status는 pending 유지 (success 불가)
- Approve로 override 불가 (failure만 override 가능)
- 재시도하려면 푸시해서 새 커밋으로

### Q: workflow_dispatch로 잘못된 PR 번호를 입력하면?
- job이 에러로 실패함
- 슬롯에 영향 없음

---

## 대상 브랜치

### Q: 어떤 PR이 리뷰 대상인가?
- main 또는 master 브랜치를 대상으로 하는 PR만
- 예: feature → main (리뷰 대상)
- 예: feature → develop (리뷰 대상 아님)

### Q: 대상이 아닌 PR은 어떻게 되나?
- 워크플로우 자체가 트리거되지 않음
- 라벨 추가 안 됨, 리뷰 안 됨
- PR Review Status 체크 없이 그냥 머지 가능

### Q: 기본 브랜치가 main/master가 아니면?
- `pr-review.yml`의 `branches: [main, master]` 부분을 수정해야 함
- 예: `branches: [develop]` 또는 `branches: [main, master, develop]`
- GitHub Actions의 branches 필터는 변수 사용 불가 (yml 직접 수정 필요)

---

## 슬롯 덮어쓰기

### Q: 이미 채워진 슬롯에 다시 쓸 수 있나?
- 불가능
- 빈 슬롯만 찾아서 채움
- 이유: 덮어쓰기 허용하면 실패를 성공으로 바꾸는 게이밍 가능

---

## Fork PR

### Q: fork에서 만든 PR은 어떻게 되나?
- GitHub 정책상 fork PR은 GITHUB_TOKEN 권한이 제한됨
- status 쓰기, 라벨 추가 등이 안 될 수 있음
- 이건 GitHub 정책이므로 변경 불가

---

## PR 상태 변경

### Q: 리뷰 진행 중에 PR이 닫히면?
- 이미 실행 중인 리뷰는 계속 진행됨 (자동 중단 안 됨)
- 드문 케이스라 별도 처리 안 함

---

## 기술 구현

### Q: AI API 호출에 Tool Use를 쓰는 이유는?
- AI 응답을 구조화된 형식(pass/fail + 상세 내용)으로 강제
- 자유 형식 텍스트 파싱 불필요 → 안정적인 결과 추출
- AI가 "pass" 또는 "fail" 외의 값을 반환할 수 없음
