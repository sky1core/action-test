#!/bin/bash
# Unit Test Report Script
# Usage: bash unit-test-report.sh <head_sha> <pr_number> <test_passed>
# Env: GITHUB_TOKEN, GITHUB_API_URL, GITHUB_REPOSITORY, GITHUB_SERVER_URL, GITHUB_RUN_ID, GITHUB_RUN_NUMBER

set +e

HEAD_SHA="$1"
PR_NUMBER="$2"
TEST_PASSED="$3"

SHORT_SHA="${HEAD_SHA:0:7}"

# GitHub uses run_id in URL, Gitea uses run_number
# Note: Gitea's github.run_number incorrectly returns run_id, so we query API to get correct run_number
if [[ "$GITHUB_SERVER_URL" == *"github.com"* ]]; then
  RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
else
  # Gitea: Query API to get correct run_number from run_id
  ACTUAL_RUN_NUMBER=$(curl -sf -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID" \
    | jq -r '.run_number // empty' 2>/dev/null)
  if [ -n "$ACTUAL_RUN_NUMBER" ]; then
    RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${ACTUAL_RUN_NUMBER}"
  else
    # Fallback to run_id if API fails
    RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
  fi
fi

if [ "$TEST_PASSED" = "true" ]; then
  STATE="success"
  DESC="Check passed"
else
  STATE="failure"
  DESC="Check failed"
fi

# Set commit status
echo "Setting commit status..."
curl -sS -f -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/statuses/$HEAD_SHA" \
  -d "{\"state\":\"$STATE\",\"context\":\"unit-test\",\"description\":\"$DESC\"}" || echo "Warning: Status API failed"

# Build comment
echo "Building comment..."
if [ "$TEST_PASSED" = "true" ]; then
  {
    echo "## ✅ unit-test - PASS"
    echo ""
    echo "🔗 [상세 로그]($RUN_URL) | 📌 $SHORT_SHA"
    echo ""
    echo "\`/test\` 명령에 대한 응답"
  } > comment.md
else
  {
    printf '## ❌ unit-test - FAIL\n\n```\n'
    tail -50 test_output.txt 2>/dev/null || echo "(no output)"
    printf '\n```\n\n'
    echo "🔗 [상세 로그]($RUN_URL) | 📌 $SHORT_SHA"
    echo ""
    echo "\`/test\` 명령에 대한 응답"
  } > comment.md
fi

# Post PR comment
echo "Posting comment..."
BODY=$(jq -Rs '.' comment.md)
curl -sS -f -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" \
  -d "{\"body\": $BODY}" || echo "Warning: Comment API failed"

# Save result for later steps
echo "$TEST_PASSED" > test_result.txt
echo "Done."
