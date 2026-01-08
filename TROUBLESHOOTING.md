# 문제 해결 및 주의사항

## 주의사항

워크플로우를 수정하거나 확장할 때 알아야 할 제약사항들입니다.

### GITHUB_TOKEN 권한 제한

GITHUB_TOKEN으로는 PR을 Draft로 변환할 수 없습니다.
```
Error: Resource not accessible by integration
```
Draft 변환이 필요하면 PAT 또는 GitHub App 토큰이 필요합니다.

### 새 워크플로우의 pull_request 트리거 제한

새로 만든 워크플로우 파일은 **main에 머지된 후에야** `pull_request` 이벤트로 트리거됩니다.
- PR 브랜치에만 워크플로우를 추가하면 `pull_request` 이벤트에서 실행 안 됨
- 해결: 기존 워크플로우에 기능 통합 또는 먼저 main에 머지

### Status API는 이모지 불가

Status description에 이모지(4-byte Unicode)를 넣으면 실패합니다.
```yaml
# ❌ 실패
-f description="✅ AI 리뷰 통과"

# ✅ 성공
-f description="AI 리뷰 통과"
```

### YAML 멀티라인 문자열

GitHub Actions에서 멀티라인 문자열을 직접 사용하면 파싱 오류가 발생할 수 있습니다.
```yaml
# ❌ 파싱 오류 가능
run: |
  gh pr comment 1 --body "## 제목
  내용"

# ✅ 파일로 저장 후 사용
run: |
  echo "## 제목" > comment.md
  gh pr comment 1 --body-file comment.md
```

### gh CLI는 checkout 필수

`gh pr list`, `gh pr view` 등은 git repository 컨텍스트가 필요합니다.
```yaml
steps:
  - uses: actions/checkout@v4  # 필수!
  - run: gh pr list ...
```

### pull_request 이벤트 타입

PR 생성, 라벨 제거, 푸시를 모두 감지하려면 타입을 명시해야 합니다.
```yaml
on:
  pull_request:
    types: [opened, unlabeled, synchronize]
```

- `opened`: PR 생성 시
- `unlabeled`: 라벨 제거 시
- `synchronize`: PR에 푸시 시 (PR이 열려있을 때만 트리거됨)

> 참고: `push` 트리거와 달리 `synchronize`는 PR이 열린 상태에서만 트리거됩니다.

### OAuth App으로 워크플로우 수정 불가

Claude Code 등 OAuth App 토큰으로는 워크플로우 파일을 push할 수 없습니다.
```
Error: refusing to allow an OAuth App to create or update workflow without workflow scope
```

## 자주 묻는 문제

### 라벨이 자동 추가되지 않음
- Workflow permissions이 "Read and write"인지 확인

### Status check가 보이지 않음
- Branch protection에서 `merge-gate`를 추가했는지 확인

### 리뷰가 스킵됨
- `🚧 not-ready` 라벨이 붙어있는지 확인
- 쿨다운 시간 내인지 확인 (기본 15분)
- 이미 N개 리뷰가 완료되었는지 확인

### 푸시했더니 이전 통과 기록이 사라짐
이것은 정상 동작입니다. 푸시하면 새 커밋이 되고, status check는 커밋 단위로 관리됩니다. 새 커밋에서 다시 N개의 리뷰를 통과해야 합니다.

이 설계의 목적:
- 코드가 변경되면 이전 리뷰 결과는 무효
- "푸시로 실패 리셋해서 재시도"를 해도 통과 기록도 같이 리셋되므로 게이밍 불가

### workflow_dispatch가 PR 브랜치의 워크플로우 변경을 반영 안 함
workflow_dispatch는 **디폴트 브랜치의 workflow 파일**을 사용합니다.

- **워크플로우 YAML 파일**: 디폴트 브랜치 것 사용 (프롬프트, job 정의 등)
- **리뷰 대상 코드**: PR의 diff (`gh pr diff`로 가져옴)

즉, PR 브랜치에서 워크플로우를 수정해도 수동 실행 시 반영되지 않습니다.
단, PR의 코드 변경사항은 정상적으로 리뷰됩니다.

해결: 워크플로우 변경은 디폴트 브랜치에 머지한 후 수동 실행

### AI 리뷰가 pending 상태로 멈춤
AI API 호출이 실패하거나 워크플로우가 중단되면 슬롯이 pending 상태로 남습니다.

증상:
- `ai-review-N`이 pending 상태로 고정
- `merge-gate`도 pending 유지
- Approve해도 override 안 됨 (failure만 override 가능)

해결: 푸시해서 새 커밋으로 재시작 (이전 기록 전부 무효화)
