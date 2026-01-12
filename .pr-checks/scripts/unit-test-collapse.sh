#!/bin/bash
# Collapse Old Comments Script
# Usage: bash collapse-comments.sh <pr_number> <head_sha>
# Env: GITHUB_TOKEN, GITHUB_API_URL, GITHUB_REPOSITORY

set +e

PR_NUMBER="$1"
HEAD_SHA="$2"
SHORT_SHA="${HEAD_SHA:0:7}"
MARKER_PREFIX="## ❌ unit-test"

# Get comments and collapse old ones
COMMENTS=$(curl -sf -H "Authorization: token $GITHUB_TOKEN" \
  "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments" \
  | jq "[.[] | select(.body | startswith(\"$MARKER_PREFIX\")) | select(.body | contains(\"<details>\") | not) | {id, body}]")

echo "$COMMENTS" | jq -c '.[]' | while read -r comment; do
  COMMENT_ID=$(echo "$comment" | jq -r '.id')
  BODY=$(echo "$comment" | jq -r '.body')

  # Skip current commit's comment
  if echo "$BODY" | grep -q "📌 $SHORT_SHA"; then
    echo "Skipping current commit comment: $COMMENT_ID"
    continue
  fi

  echo "Collapsing comment: $COMMENT_ID"
  FIRST_LINE=$(echo "$BODY" | head -1)
  REST=$(echo "$BODY" | tail -n +2)

  printf '%s\n\n<details>\n<summary>펼쳐서 보기</summary>\n%s\n</details>' "$FIRST_LINE" "$REST" > new_body.md

  PATCH_BODY=$(jq -Rs '.' new_body.md)
  curl -sf -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    -X PATCH "$GITHUB_API_URL/repos/$GITHUB_REPOSITORY/issues/comments/$COMMENT_ID" \
    -d "{\"body\": $PATCH_BODY}" || echo "Warning: Failed to collapse $COMMENT_ID"
done
