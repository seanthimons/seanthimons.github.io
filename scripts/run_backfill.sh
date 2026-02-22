#!/usr/bin/env bash
#
# US-002: Sequential Runner — iterates the week manifest and invokes
# the /tidy-tuesday skill in autonomous mode for each week.
#
# Usage:
#   ./scripts/run_backfill.sh                  # run all weeks
#   ./scripts/run_backfill.sh --dry-run        # preview what would run
#   ./scripts/run_backfill.sh --start-from N   # skip first N entries (0-indexed)
#   ./scripts/run_backfill.sh --batch N        # stop after N posts generated
#   ./scripts/run_backfill.sh --verbose        # show Claude output in real time
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PROJECT_DIR/tasks/week_manifest.json"
POSTS_DIR="$PROJECT_DIR/posts"
LOG_FILE="$PROJECT_DIR/tasks/backfill-log.txt"

DRY_RUN=false
START_FROM=0
BATCH_SIZE=0
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --start-from)
      START_FROM="$2"
      shift 2
      ;;
    --batch)
      BATCH_SIZE="$2"
      shift 2
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Validate manifest exists
if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: Manifest not found at $MANIFEST"
  exit 1
fi

# Counters
total=0
generated=0
skipped=0
failed=0
failed_weeks=""
commits_since_push=0
PUSH_BATCH_SIZE=10

# Read manifest length
entry_count=$(jq 'length' "$MANIFEST")

echo "=========================================="
echo "Tidy Tuesday Backfill Runner"
echo "=========================================="
echo "Manifest:    $MANIFEST"
echo "Entries:     $entry_count"
echo "Posts dir:   $POSTS_DIR"
echo "Start from:  $START_FROM"
echo "Batch size:  ${BATCH_SIZE:-all}"
echo "Dry run:     $DRY_RUN"
echo "Verbose:     $VERBOSE"
echo "Log file:    $LOG_FILE"
echo "=========================================="
echo ""

# Initialize log
{
  echo "=========================================="
  echo "Backfill run started: $(date -Iseconds)"
  echo "=========================================="
} >> "$LOG_FILE"

for i in $(seq 0 $((entry_count - 1))); do
  # Skip entries before start-from
  if [[ $i -lt $START_FROM ]]; then
    continue
  fi

  total=$((total + 1))

  # Extract fields from manifest entry
  week_date=$(jq -r ".[$i].week_date" "$MANIFEST")
  dataset_name=$(jq -r ".[$i].dataset_name" "$MANIFEST")
  dataset_slug=$(jq -r ".[$i].dataset_slug" "$MANIFEST")
  year=$(jq -r ".[$i].year" "$MANIFEST")
  week_number=$(jq -r ".[$i].week_number" "$MANIFEST")
  is_byod=$(jq -r ".[$i].is_byod" "$MANIFEST")
  sub_year=$(jq -r ".[$i].substituted_from.year // empty" "$MANIFEST")
  sub_date=$(jq -r ".[$i].substituted_from.date // empty" "$MANIFEST")

  echo "---"
  echo "[$((i + 1))/$entry_count] $week_date — $dataset_name  (generated: $generated | skipped: $skipped | failed: $failed)"

  # US-003: Rescan posts/ for existing post before each week
  if ls "$POSTS_DIR"/${week_date}* 1>/dev/null 2>&1; then
    echo "  Skipping week $week_date — post already exists"
    echo "  SKIP $week_date $dataset_name (already exists)" >> "$LOG_FILE"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would invoke /tidy-tuesday for $week_date ($dataset_name)"
    echo "  DRY-RUN $week_date $dataset_name" >> "$LOG_FILE"
    continue
  fi

  # Build the dataset date for tt_load()
  # For BYOD weeks with a substitution, use the substituted date
  if [[ "$is_byod" == "true" && -n "$sub_date" ]]; then
    tt_load_date="$sub_date"
    byod_note="This is a BYOD (Bring Your Own Data) week. Using substituted 2024 dataset from $sub_date (year $sub_year).
Add 'substituted_from: \"$sub_date\"' to the YAML frontmatter.
In the introductory text, note that this week was originally BYOD and the analysis uses $dataset_name from the 2024 TidyTuesday archive ($sub_date) as a substitute."
  else
    tt_load_date="$week_date"
    byod_note=""
  fi

  # Construct the prompt for autonomous /tidy-tuesday invocation
  prompt=$(cat <<PROMPT
/tidy-tuesday

Run in autonomous mode (hands-off, unattended).

Dataset: "$dataset_name"
Dataset date for tt_load(): $tt_load_date
Post date (for the output folder and frontmatter date field): $week_date

The post MUST be created at: posts/$week_date/$week_date.qmd
The frontmatter date field MUST be: "$week_date"

${byod_note}

Do NOT use Sys.Date() for the post date — use exactly "$week_date" as the post date.
The dataset date for tt_load() is "$tt_load_date".

Generate the full Tidy Tuesday analysis: EDA, domain analysis, visualizations, and narrative.
PROMPT
)

  start_ts=$(date +%s)
  echo "  Invoking /tidy-tuesday skill... (started $(date +%H:%M:%S))"

  # Background heartbeat: prints elapsed time every 30s so the terminal looks alive
  (
    while true; do
      sleep 30
      elapsed_hb=$(( $(date +%s) - start_ts ))
      printf "  ... still working (%dm %ds elapsed)\n" $((elapsed_hb / 60)) $((elapsed_hb % 60))
    done
  ) &
  heartbeat_pid=$!
  trap "kill $heartbeat_pid 2>/dev/null" EXIT

  # Run claude in print mode with permissions bypassed for automation
  # In verbose mode, stream JSON events and extract tool-use progress;
  # otherwise capture quietly (heartbeat provides liveness)
  if [[ "$VERBOSE" == "true" ]]; then
    echo "  ---- Claude trace ----"
    # Stream JSON events and extract a readable progress trace
    CLAUDECODE= claude -p \
      --dangerously-skip-permissions \
      --model sonnet \
      --output-format stream-json \
      --allowedTools "Bash Edit Read Write Glob Grep Skill WebFetch WebSearch" \
      --max-budget-usd 1.50 \
      "$prompt" \
      2>>"$LOG_FILE" \
    | stdbuf -oL jq -r --unbuffered '
        if .type == "assistant" and .subtype == "tool_use" then
          "  [tool] \(.tool_name // "unknown"): \(.tool_input_preview // .tool_input.command // .tool_input.pattern // .tool_input.file_path // "" | tostring | .[0:120])"
        elif .type == "result" then
          "  [done] cost=$\(.cost_usd // "?") duration=\(.duration_ms // "?")"
        else empty end
      ' 2>/dev/null \
    | tee -a "$LOG_FILE"
    claude_exit=${PIPESTATUS[0]}
    echo "  ---- end Claude trace ----"
  else
    if CLAUDECODE= claude -p \
      --dangerously-skip-permissions \
      --model sonnet \
      --allowedTools "Bash Edit Read Write Glob Grep Skill WebFetch WebSearch" \
      --max-budget-usd 1.50 \
      "$prompt" \
      2>>"$LOG_FILE" 1>/dev/null; then
      claude_exit=0
    else
      claude_exit=$?
    fi
  fi

  # Stop the heartbeat
  kill $heartbeat_pid 2>/dev/null
  wait $heartbeat_pid 2>/dev/null

  elapsed=$(( $(date +%s) - start_ts ))
  elapsed_fmt="$(( elapsed / 60 ))m $(( elapsed % 60 ))s"
  echo "  Finished in $elapsed_fmt (exit code $claude_exit)"

  if [[ $claude_exit -eq 0 ]]; then

    # Verify the post was actually created
    if [[ -f "$POSTS_DIR/$week_date/$week_date.qmd" ]]; then
      echo "  SUCCESS: Post created at posts/$week_date/$week_date.qmd"
      echo "  OK $week_date $dataset_name" >> "$LOG_FILE"
      generated=$((generated + 1))

      # US-004: Stage and commit only this post's directory
      if git -C "$PROJECT_DIR" add "posts/$week_date/" && \
         git -C "$PROJECT_DIR" commit -m "Add Tidy Tuesday post: $week_date $dataset_name" 2>>"$LOG_FILE"; then
        echo "  COMMITTED: Add Tidy Tuesday post: $week_date $dataset_name"
        echo "  COMMIT $week_date $dataset_name" >> "$LOG_FILE"
        commits_since_push=$((commits_since_push + 1))

        # US-005: Batch push to remote every PUSH_BATCH_SIZE commits
        if [[ $commits_since_push -ge $PUSH_BATCH_SIZE ]]; then
          echo "  Pushing batch of $commits_since_push commits to remote..."
          if git -C "$PROJECT_DIR" push 2>>"$LOG_FILE"; then
            echo "  PUSHED $commits_since_push commits" >> "$LOG_FILE"
            echo "  PUSH OK: $commits_since_push commits pushed to remote"
            commits_since_push=0
          else
            echo "  PUSH FAIL: Push failed, will retry after next batch" >> "$LOG_FILE"
            echo "  WARN: Push to remote failed — will retry after next batch"
          fi
        fi
      else
        echo "  WARN: git commit failed for $week_date"
        echo "  COMMIT-FAIL $week_date $dataset_name" >> "$LOG_FILE"
      fi
    else
      echo "  WARN: Claude exited 0 but post file not found at posts/$week_date/$week_date.qmd"
      echo "  FAIL $week_date $dataset_name (post file not created)" >> "$LOG_FILE"
      failed=$((failed + 1))
      failed_weeks="$failed_weeks\n  - $week_date: $dataset_name (post file not created)"
    fi
  else
    echo "  FAIL: Error generating post for $week_date"
    echo "  FAIL $week_date $dataset_name (claude error)" >> "$LOG_FILE"
    failed=$((failed + 1))
    failed_weeks="$failed_weeks\n  - $week_date: $dataset_name (claude error)"
  fi

  # Batch size limit: stop after N posts generated
  if [[ $BATCH_SIZE -gt 0 && $generated -ge $BATCH_SIZE ]]; then
    echo "Batch limit reached ($BATCH_SIZE posts generated). Stopping."
    echo "  BATCH-STOP after $generated posts" >> "$LOG_FILE"
    break
  fi

  echo ""
done

# US-005: Push any remaining commits at the end of the run
if [[ $commits_since_push -gt 0 ]]; then
  echo "Pushing final batch of $commits_since_push commits to remote..."
  if git -C "$PROJECT_DIR" push 2>>"$LOG_FILE"; then
    echo "  PUSHED final $commits_since_push commits" >> "$LOG_FILE"
    echo "PUSH OK: Final $commits_since_push commits pushed to remote"
    commits_since_push=0
  else
    echo "  PUSH FAIL: Final push failed" >> "$LOG_FILE"
    echo "WARN: Final push to remote failed — run 'git push' manually"
  fi
fi

# Print summary
echo "=========================================="
echo "Backfill Run Summary"
echo "=========================================="
echo "Total weeks processed: $total"
echo "Posts generated:       $generated"
echo "Posts skipped:         $skipped"
echo "Posts failed:          $failed"
if [[ -n "$failed_weeks" ]]; then
  echo ""
  echo "Failed weeks:"
  echo -e "$failed_weeks"
fi
echo "=========================================="

# Save summary to log
{
  echo ""
  echo "=========================================="
  echo "Run completed: $(date -Iseconds)"
  echo "Total: $total | Generated: $generated | Skipped: $skipped | Failed: $failed"
  if [[ -n "$failed_weeks" ]]; then
    echo "Failed weeks:"
    echo -e "$failed_weeks"
  fi
  echo "=========================================="
  echo ""
} >> "$LOG_FILE"
