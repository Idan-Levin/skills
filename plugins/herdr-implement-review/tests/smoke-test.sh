#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat > "$tmp/bin/herdr" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >> "$MOCK_LOG"; printf '\n' >> "$MOCK_LOG"
case "$1 $2" in
  'agent prompt')
    prompt="${4:-}"
    if [[ "$prompt" == *"plan.md"* ]]; then
      printf 'plan\nREVIEW_LEVEL: %s\nCONTROL_STATUS: %s\n' "$MOCK_REVIEW_LEVEL" "$MOCK_PLAN_STATUS" > "$RUN_DIR/plan.md"
    fi
    if [[ "$prompt" == *"implementation-0.md"* ]]; then printf 'implementation\n' > "$RUN_DIR/implementation-0.md"; fi
    if [[ "$prompt" == *"mother-review-0.md"* ]]; then printf 'review\nCONTROL_STATUS: APPROVE\n' > "$RUN_DIR/mother-review-0.md"; fi
    ;;
  'pane split')
    n="$(grep -c '^pane split' "$MOCK_LOG" || true)"
    printf '{"result":{"pane":{"pane_id":"pane-%s"}}}' "$n"
    ;;
  'pane get')
    printf '{"result":{"pane":{"agent":"codex","foreground_cwd":"%s"}}}' "$MOCK_CWD"
    ;;
  'pane run')
    bash -c "${4:?missing pane command}"
    ;;
  'pane wait-output')
    [[ "${MOCK_WAIT_FAIL:-0}" != 1 ]]
    ;;
esac
EOF

cat > "$tmp/bin/npx" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" > "$MOCK_NPX_LOG"
printf 'mock security scan\n'
EOF
chmod +x "$tmp/bin/herdr" "$tmp/bin/npx"

run_case() {
  local name="$1" level="$2" plan_status="$3" wait_fail="${4:-0}" case_root
  case_root="$tmp/$name"
  mkdir -p "$case_root/state/runs/seed"
  : > "$case_root/herdr.log"
  : > "$case_root/npx.log"
  export PATH="$tmp/bin:$PATH"
  export HERDR_BIN_PATH=herdr HERDR_PLUGIN_STATE_DIR="$case_root/state" HERDR_PANE_ID=mother HERDR_WORKSPACE_ID=workspace
  export MOCK_LOG="$case_root/herdr.log" MOCK_NPX_LOG="$case_root/npx.log" MOCK_CWD="$root"
  export MOCK_REVIEW_LEVEL="$level" MOCK_PLAN_STATUS="$plan_status" RUN_DIR="$case_root/state/runs/seed"
  export MOCK_WAIT_FAIL="$wait_fail"
  export IMPLEMENT_REVIEW_MAX_REVISIONS=0

  if [[ "$plan_status" != "APPROVE" ]]; then
    ! bash "$root/scripts/run-workflow.sh" > "$case_root/output.log" 2>&1
    ! grep -q '^pane split' "$MOCK_LOG"
    grep -q 'Mother plan must end with CONTROL_STATUS: APPROVE' "$case_root/output.log"
    return
  fi

  if [[ "$wait_fail" == 1 ]]; then
    ! bash "$root/scripts/run-workflow.sh" > "$case_root/output.log" 2>&1
    grep -q '^pane send-keys pane-2 ctrl+c' "$MOCK_LOG"
    return
  fi

  bash "$root/scripts/run-workflow.sh" > "$case_root/output.log"
  run_dir="$(find "$case_root/state/runs" -mindepth 1 -maxdepth 1 -type d ! -name seed -print -quit)"
  grep -q 'agent start implementer --kind codex --pane pane-1' "$MOCK_LOG"
  grep -q 'Approved by mother process' "$case_root/output.log"
  test -f "$run_dir/baseline.status"

  if [[ "$level" == "LIGHT" ]]; then
    ! grep -q '^pane run' "$MOCK_LOG"
    grep -q '^SKIPPED$' "$run_dir/security-0.status"
  else
    grep -q '^pane run pane-2' "$MOCK_LOG"
    grep -q '@openai/codex-security@0.1.8' "$MOCK_NPX_LOG"
    grep -q 'mock security scan' "$run_dir/security-0.log"
    grep -q '^0$' "$run_dir/security-0.status"
  fi
}

run_case light LIGHT APPROVE
run_case deep DEEP APPROVE
run_case rejected LIGHT REVISE
run_case cancelled DEEP APPROVE 1
printf 'smoke test passed\n'
