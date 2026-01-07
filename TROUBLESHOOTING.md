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
-f description="✅ AI 검사 통과"

# ✅ 성공
-f description="AI 검사 통과"
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

PR 생성과 라벨 제거를 모두 감지하려면 타입을 명시해야 합니다.
```yaml
on:
  pull_request:
    types: [opened, unlabeled]
```

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

### 검사가 스킵됨
- `🚧 not-ready` 라벨이 붙어있는지 확인
- 쿨다운 시간 내인지 확인 (기본 5분)
- 이미 N개 검사가 완료되었는지 확인
