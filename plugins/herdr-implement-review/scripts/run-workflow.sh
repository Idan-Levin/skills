#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly MAX_REVISIONS="${IMPLEMENT_REVIEW_MAX_REVISIONS:-2}"
readonly HERDR="${HERDR_BIN_PATH:-herdr}"
readonly SECURITY_PACKAGE="@openai/codex-security@0.1.8"
readonly STATE_ROOT="${HERDR_PLUGIN_STATE_DIR:?Herdr did not provide plugin state}"
readonly MOTHER_PANE="${HERDR_PANE_ID:?Run this action from the mother Claude or Codex pane}"
readonly RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
readonly RUN_DIR="$STATE_ROOT/runs/$RUN_ID"

security_pane=""
scan_running=0

mkdir -p "$RUN_DIR"

die() { printf 'implement-review: %s\n' "$*" >&2; exit 1; }
json_field() {
  local field="$1"
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);const p=process.argv[1].split(".");let v=o;for(const k of p)v=v?.[k];if(v==null||v==="")process.exit(2);process.stdout.write(String(v))})' "$field"
}
wait_for_file() {
  local path="$1" seconds="${2:-600}" elapsed=0
  while [[ ! -s "$path" ]]; do
    (( elapsed >= seconds )) && die "Timed out waiting for $path"
    sleep 2
    ((elapsed += 2))
  done
}
mother_prompt() {
  "$HERDR" agent prompt "$MOTHER_PANE" "$1" --wait --timeout 600000
}
status_from() {
  sed -nE 's/^CONTROL_STATUS:[[:space:]]*(APPROVE|REVISE)[[:space:]]*$/\1/p' "$1" | tail -n 1
}
review_level_from() {
  sed -nE 's/^REVIEW_LEVEL:[[:space:]]*(LIGHT|DEEP)[[:space:]]*$/\1/p' "$1" | tail -n 1
}
last_nonempty_line() {
  sed '/^[[:space:]]*$/d' "$1" | tail -n 1
}
stop_security_scan() {
  if (( scan_running )) && [[ -n "$security_pane" ]]; then
    scan_running=0
    "$HERDR" pane send-keys "$security_pane" ctrl+c >/dev/null 2>&1 || true
  fi
}
trap stop_security_scan EXIT
trap 'stop_security_scan; exit 130' INT TERM

[[ "$MAX_REVISIONS" =~ ^[0-9]+$ ]] || die "IMPLEMENT_REVIEW_MAX_REVISIONS must be a non-negative integer"

mother_pane_json="$("$HERDR" pane get "$MOTHER_PANE")" || die "Could not inspect the mother pane"
mother_agent="$(printf '%s' "$mother_pane_json" | json_field result.pane.agent)" \
  || die "Mother pane has no agent"
case "$mother_agent" in claude|codex) ;; *) die "Run this action from a Claude or Codex pane";; esac
mother_cwd="$(printf '%s' "$mother_pane_json" | json_field result.pane.foreground_cwd)" \
  || mother_cwd="$(printf '%s' "$mother_pane_json" | json_field result.pane.cwd)" \
  || die "Mother pane has no working directory"
ROOT_CWD="$(cd "$mother_cwd" && pwd -P)" || die "Mother pane working directory is unavailable: $mother_cwd"
readonly ROOT_CWD

if git -C "$ROOT_CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$ROOT_CWD" status --short --untracked-files=all > "$RUN_DIR/baseline.status"
  git -C "$ROOT_CWD" diff --binary > "$RUN_DIR/baseline.diff"
  git -C "$ROOT_CWD" diff --binary --cached >> "$RUN_DIR/baseline.diff"
  git -C "$ROOT_CWD" rev-parse HEAD > "$RUN_DIR/baseline.commit" 2>/dev/null \
    || printf 'UNBORN\n' > "$RUN_DIR/baseline.commit"
else
  printf 'Not a Git worktree.\n' > "$RUN_DIR/baseline.status"
  : > "$RUN_DIR/baseline.diff"
  : > "$RUN_DIR/baseline.commit"
fi

cat > "$RUN_DIR/README.md" <<EOF
# Implement + Security Review run

Mother pane: $MOTHER_PANE
Repository: $ROOT_CWD
Review level: pending mother plan

The invoking $mother_agent pane is the sole planning and review authority.
Initial Git evidence is in baseline.status, baseline.diff, and baseline.commit.
EOF

cat > "$RUN_DIR/mother-plan.instructions.md" <<EOF
You are the mother process for an implementation workflow. Use the concrete task
already in your current conversation and inspect the repository if necessary.
Write a complete implementation brief to:

  $RUN_DIR/plan.md

Include the objective, acceptance criteria, relevant files and constraints, test
commands, and explicit security considerations. Record an exact REVIEW_LEVEL:
LIGHT or REVIEW_LEVEL: DEEP line. Choose LIGHT for small, local, dependency-free
changes without sensitive data or trust-boundary changes. Choose DEEP for changes
to authentication, authorization, secrets, payments, external input, networking,
dependencies, permissions, or other meaningful trust boundaries.

Do not edit application source. Finish the file with exactly:
CONTROL_STATUS: APPROVE
EOF

mother_prompt "$(cat "$RUN_DIR/mother-plan.instructions.md")"
wait_for_file "$RUN_DIR/plan.md"
[[ "$(last_nonempty_line "$RUN_DIR/plan.md")" == "CONTROL_STATUS: APPROVE" ]] \
  || die "Mother plan must end with CONTROL_STATUS: APPROVE"
review_level="$(review_level_from "$RUN_DIR/plan.md")"
[[ -n "$review_level" ]] || die "Mother plan needs REVIEW_LEVEL: LIGHT or REVIEW_LEVEL: DEEP"
readonly review_level

impl_json="$("$HERDR" pane split "$MOTHER_PANE" --direction right --cwd "$ROOT_CWD" --no-focus)"
impl_pane="$(printf '%s' "$impl_json" | json_field result.pane.pane_id)" || die "Could not create the Codex Implementer pane"
"$HERDR" pane rename "$impl_pane" "Codex Implementer"

if [[ "$review_level" == "DEEP" ]]; then
  security_json="$("$HERDR" pane split "$impl_pane" --direction down --cwd "$ROOT_CWD" --no-focus)"
  security_pane="$(printf '%s' "$security_json" | json_field result.pane.pane_id)" || die "Could not create the Codex Security pane"
  "$HERDR" pane rename "$security_pane" "Codex Security"
else
  security_pane="not-created-light-review"
fi

cat >> "$RUN_DIR/README.md" <<EOF
Implementer pane: $impl_pane
Security pane: $security_pane
Review level: $review_level
EOF

"$HERDR" agent start implementer --kind codex --pane "$impl_pane" --timeout 120000

run_security_scan() {
  local cycle="$1" sentinel="IMPLEMENT_REVIEW_SECURITY_DONE_${RUN_ID}_${cycle}"
  if [[ "$review_level" == "LIGHT" ]]; then
    printf '%s\n' 'LIGHT review selected by mother plan; no model security scan run.' > "$RUN_DIR/security-$cycle.log"
    printf 'SKIPPED\n' > "$RUN_DIR/security-$cycle.status"
    return
  fi

  cat > "$RUN_DIR/run-security-$cycle.sh" <<EOF
#!/usr/bin/env bash
set -o pipefail
cd $(printf '%q' "$ROOT_CWD")
npx --yes $SECURITY_PACKAGE scan . --mode deep 2>&1 | tee $(printf '%q' "$RUN_DIR/security-$cycle.log")
scan_status=\${PIPESTATUS[0]}
printf '%s\\n' "\$scan_status" > $(printf '%q' "$RUN_DIR/security-$cycle.status")
printf '%s:%s\\n' '$sentinel' "\$scan_status"
exit "\$scan_status"
EOF
  chmod 700 "$RUN_DIR/run-security-$cycle.sh"
  scan_running=1
  "$HERDR" pane run "$security_pane" "bash $(printf '%q' "$RUN_DIR/run-security-$cycle.sh")"
  "$HERDR" pane wait-output "$security_pane" --match "$sentinel" --source recent-unwrapped --lines 1000 --timeout 1800000 \
    || die "Timed out waiting for Codex Security scan $cycle"
  scan_running=0
  [[ -s "$RUN_DIR/security-$cycle.status" ]] || die "Codex Security scan $cycle did not record an exit status"
}

for ((cycle=0; cycle<=MAX_REVISIONS; cycle++)); do
  if (( cycle == 0 )); then
    "$HERDR" agent prompt implementer "You are the Codex implementer. Read the mother-approved brief at $RUN_DIR/plan.md and the initial Git evidence in $RUN_DIR/baseline.status and $RUN_DIR/baseline.diff. Preserve pre-existing work. Implement the task in $ROOT_CWD, run the listed checks, and record a factual handoff in $RUN_DIR/implementation-0.md: changed files, tests and results, remaining risks. You may edit only application source and tests; do not edit workflow files." --wait --timeout 1800000
  else
    "$HERDR" agent prompt implementer "The mother requested revisions. Read $RUN_DIR/mother-review-$((cycle-1)).md, fix every actionable issue in $ROOT_CWD while preserving pre-existing work, run relevant tests, and write $RUN_DIR/implementation-$cycle.md with changes and results. Do not edit workflow files." --wait --timeout 1800000
  fi
  wait_for_file "$RUN_DIR/implementation-$cycle.md"

  run_security_scan "$cycle"
  cat > "$RUN_DIR/mother-review.instructions-$cycle.md" <<EOF
You are the mother process and final reviewer. Review the actual repository diff,
the initial Git evidence in $RUN_DIR/baseline.status and $RUN_DIR/baseline.diff,
the implementation handoff at $RUN_DIR/implementation-$cycle.md, and the security
evidence at $RUN_DIR/security-$cycle.log and $RUN_DIR/security-$cycle.status.
SKIPPED means the approved LIGHT review did not run the model scanner. You still
own correctness, tests, and security quality. Do not edit source code yourself.

Write your decision to $RUN_DIR/mother-review-$cycle.md. Include a concise review
of correctness, tests, and security findings. If anything must change, provide
precise prioritized instructions and finish with exactly CONTROL_STATUS: REVISE.
Only approve when the evidence is acceptable; explain accepted security findings.
Finish with exactly CONTROL_STATUS: APPROVE when ready.
EOF
  mother_prompt "$(cat "$RUN_DIR/mother-review.instructions-$cycle.md")"
  wait_for_file "$RUN_DIR/mother-review-$cycle.md"
  decision="$(status_from "$RUN_DIR/mother-review-$cycle.md")"
  [[ -n "$decision" && "$(last_nonempty_line "$RUN_DIR/mother-review-$cycle.md")" == "CONTROL_STATUS: $decision" ]] \
    || die "Mother review must end with CONTROL_STATUS: APPROVE or CONTROL_STATUS: REVISE"
  if [[ "$decision" == "APPROVE" ]]; then
    printf 'Approved by mother process. Evidence: %s\n' "$RUN_DIR"
    exit 0
  fi
done

die "Mother requested more than $MAX_REVISIONS revision cycles. See $RUN_DIR."
