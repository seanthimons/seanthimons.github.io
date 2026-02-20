#!/usr/bin/env bash
#
# US-002: Sequential Runner — iterates the week manifest and invokes
# the /tidy-tuesday skill in autonomous mode for each week.
#
# Usage:
#   ./scripts/run_backfill.sh                  # run all weeks
#   ./scripts/run_backfill.sh --dry-run        # preview what would run
#   ./scripts/run_backfill.sh --start-from N   # skip first N entries (0-indexed)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$PROJECT_DIR/tasks/week_manifest.json"
POSTS_DIR="$PROJECT_DIR/posts"
LOG_FILE="$PROJECT_DIR/tasks/backfill-log.txt"

DRY_RUN=false
START_FROM=0

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

# Read manifest length
entry_count=$(jq 'length' "$MANIFEST")

echo "=========================================="
echo "Tidy Tuesday Backfill Runner"
echo "=========================================="
echo "Manifest:    $MANIFEST"
echo "Entries:     $entry_count"
echo "Posts dir:   $POSTS_DIR"
echo "Start from:  $START_FROM"
echo "Dry run:     $DRY_RUN"
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

  echo "[$((i + 1))/$entry_count] $week_date — $dataset_name"

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
    byod_note="This is a BYOD week. Using substituted dataset from $sub_date (year $sub_year)."
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

  echo "  Invoking /tidy-tuesday skill..."

  # Run claude in print mode with permissions bypassed for automation
  if CLAUDECODE= claude -p \
    --dangerously-skip-permissions \
    --model sonnet \
    --allowedTools "Bash Edit Read Write Glob Grep Skill WebFetch WebSearch" \
    --max-budget-usd 1.50 \
    "$prompt" \
    2>>"$LOG_FILE"; then

    # Verify the post was actually created
    if [[ -f "$POSTS_DIR/$week_date/$week_date.qmd" ]]; then
      echo "  SUCCESS: Post created at posts/$week_date/$week_date.qmd"
      echo "  OK $week_date $dataset_name" >> "$LOG_FILE"
      generated=$((generated + 1))
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

  echo ""
done

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
