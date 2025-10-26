#!/bin/bash
# Adaptive Paper Pipeline Orchestrator
# Uses decision loop pattern instead of fixed steps

set -e

PROJECT_NAME="activation_function"
RUN_ID="paper_adaptive_$(date +%Y%m%d_%H%M%S)"
BASE_DIR="/Users/cstein/code/activation_function_agent"
LOG_DIR="$BASE_DIR/logs/$RUN_ID"
PAPER_DIR="$BASE_DIR/paper"
KB_DIR="/Users/cstein/vaults/projects/science/activation_function"
SOURCE_CODE="/Users/cstein/code/activation_function"
WORKFLOWS="/Users/cstein/vaults/projects/agents/workflows"

# Create log directory structure
mkdir -p "$LOG_DIR"
mkdir -p "$PAPER_DIR"

# Git: Create new branch for this run
cd "$BASE_DIR"
BRANCH_NAME="run/${RUN_ID}"
git checkout -b "$BRANCH_NAME" 2>/dev/null || git checkout "$BRANCH_NAME"
echo "Git branch: $BRANCH_NAME"

echo "=== Adaptive Paper Pipeline Orchestrator ==="
echo "Run ID: $RUN_ID"
echo "Logs: $LOG_DIR"
echo ""

# Initialize status file
cat > "$LOG_DIR/status.json" <<EOF
{
  "run_id": "$RUN_ID",
  "status": "starting",
  "goal": "Create ICML PDF from KB documentation",
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "current_action": "initializing",
  "actions_completed": [],
  "outputs": {},
  "issues": []
}
EOF

# Run adaptive orchestrator agent
cursor-agent --browser -p "You are an adaptive orchestrator for creating an ICML conference paper.

GOAL: Create complete ICML PDF with figures from KB documentation

RESOURCES:
- KB docs: $KB_DIR (CONTENT.md, COMPLETE.md)
- Source figures: $SOURCE_CODE/figures/
- Output folder: $PAPER_DIR (write-only)
- Available workflows: $WORKFLOWS/{kb_to_outline,outline_to_draft,prepare_figures,compile_latex}/README.md
- Logs: $LOG_DIR/
- Status: $LOG_DIR/status.json

YOUR JOB (Decision Loop):
1. EVALUATE current state:
   - What files exist in $PAPER_DIR?
   - What's their quality/completeness?
   - What issues exist?

2. DECIDE next action:
   - Run a workflow (kb_to_outline, outline_to_draft, prepare_figures, compile_latex)
   - Fix an issue directly (e.g., uncomment figures, fix paths)
   - Verify output quality
   - Declare done

3. EXECUTE the action

4. LOG to $LOG_DIR/orchestrator.log:
   [timestamp] [EVAL] {state}
   [timestamp] [DECIDE] {action and reasoning}
   [timestamp] [EXECUTE] {what you did}
   [timestamp] [RESULT] {outcome}

5. UPDATE $LOG_DIR/status.json

6. REPEAT until done or stuck

DECISION RULES:
- After each action, check if output is correct
- If figures are commented out in LaTeX, fix them
- If paths are wrong, fix them
- If compilation fails, read errors and fix
- If stuck after 3 fix attempts, abort with reason
- Don't blindly continue if something is wrong

EXPECTED FINAL STATE:
- $PAPER_DIR/main.pdf exists
- PDF has 8-10 pages
- PDF includes figures (not just text)
- All figures from outline are in PDF
- No compilation errors

WORKFLOWS AVAILABLE:
1. kb_to_outline: Read KB → create outline.md
2. outline_to_draft: Read outline + KB → create main.tex + references.bib
3. prepare_figures: Copy figures from source to paper/figures/
4. compile_latex: Run pdflatex + bibtex → generate PDF

NOTE: You can run workflows in any order, run them multiple times, or skip them if not needed.
You can also directly edit files to fix issues.

SAFETY:
- Read-only: $KB_DIR, $SOURCE_CODE
- Write-only: $PAPER_DIR, $LOG_DIR
- No deletions from source
- Follow $WORKFLOWS/meta/execution_safety.md

Start by evaluating current state and deciding first action.
Log every decision to $LOG_DIR/orchestrator.log" \
  --model sonnet-4.5-thinking \
  --output-format stream-json \
  -f </dev/null > "$LOG_DIR/orchestrator.jsonl" 2>&1

# Check final result
if [ -f "$PAPER_DIR/main.pdf" ]; then
  echo ""
  echo "=== Pipeline Complete ==="
  echo "PDF: $PAPER_DIR/main.pdf"
  ls -lh "$PAPER_DIR/main.pdf"
  echo ""
  echo "Logs: $LOG_DIR/"
  ls -lh "$LOG_DIR/"
else
  echo ""
  echo "=== Pipeline Failed ==="
  echo "No PDF generated. Check logs:"
  echo "$LOG_DIR/orchestrator.log"
fi

# Git: Commit results
echo ""
echo "=== Committing to Git ==="
cd "$BASE_DIR"
git add paper/ 2>/dev/null || true
git add logs/"$RUN_ID"/ 2>/dev/null || true

if [ -f "$PAPER_DIR/main.pdf" ]; then
  COMMIT_MSG="✅ $RUN_ID: Successful paper generation

- PDF: $(ls -lh "$PAPER_DIR/main.pdf" | awk '{print $5}')
- Logs: logs/$RUN_ID/
- Branch: $BRANCH_NAME"
else
  COMMIT_MSG="❌ $RUN_ID: Pipeline failed

- No PDF generated
- Logs: logs/$RUN_ID/
- Branch: $BRANCH_NAME"
fi

git commit -m "$COMMIT_MSG" 2>&1 | grep -E "files changed|insertions|deletions|create mode" || echo "No changes to commit"
echo "Committed to branch: $BRANCH_NAME"

# Backup to GCS
echo ""
echo "=== Backing up to GCS ==="
if [ -f "$BASE_DIR/backup_agent_runs.sh" ]; then
  "$BASE_DIR/backup_agent_runs.sh" 2>&1 | grep -E "===|\[2025|✅|⚠️|📊|💾|📄|📋|☁️"
  echo "Backup complete. Check: gs://ncl-agent-workflow-backups/activation_function_agent/"
else
  echo "⚠️  Backup script not found: $BASE_DIR/backup_agent_runs.sh"
fi

echo ""
echo "=== Run Complete ==="
echo "Branch: $BRANCH_NAME"
echo "To merge: git checkout main && git merge $BRANCH_NAME"
echo "To compare: git diff main..$BRANCH_NAME"

