#!/bin/bash
# Paper Pipeline Orchestrator for activation_function project
# Runs: KB → Outline → Draft → Figures → Compile

set -e  # Exit on error

PROJECT_NAME="activation_function"
RUN_ID="paper_pipeline_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="/Users/cstein/code/activation_function_agent/logs"
PAPER_DIR="/Users/cstein/code/activation_function_agent/paper"
KB_DIR="/Users/cstein/vaults/projects/science/activation_function"
SOURCE_CODE="/Users/cstein/code/activation_function"
WORKFLOWS="/Users/cstein/vaults/projects/agents/workflows"

mkdir -p "$LOG_DIR"
mkdir -p "$PAPER_DIR"

echo "=== Paper Pipeline Orchestrator ==="
echo "Run ID: $RUN_ID"
echo "Project: $PROJECT_NAME"
echo "Output: $PAPER_DIR"
echo ""

# Step 1: KB to Outline
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [START] Step 1: KB to Outline" | tee -a "$LOG_DIR/$RUN_ID.log"

cursor-agent -p "Run kb_to_outline workflow.

Task: Create paper outline from KB documentation

Input KB: $KB_DIR
Output: $PAPER_DIR/outline.md

Read CONTENT.md and COMPLETE.md from KB.
Create structured outline with:
- Section breakdown (Intro, Methods, Results, Discussion)
- Key points per section
- Recommended figures (check $SOURCE_CODE/figures/ for what exists)
- Suggested structure

Follow workflow spec: $WORKFLOWS/kb_to_outline/README.md
Safety: Read-only KB and source, write-only paper folder.
Log to: $LOG_DIR/$RUN_ID.log" \
  --model sonnet-4.5-thinking \
  --output-format stream-json \
  -f </dev/null > "$LOG_DIR/${RUN_ID}_step1_outline.jsonl" 2>&1

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [DONE] Step 1: KB to Outline" | tee -a "$LOG_DIR/$RUN_ID.log"

# Step 2: Outline to Draft
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [START] Step 2: Outline to Draft" | tee -a "$LOG_DIR/$RUN_ID.log"

cursor-agent --browser -p "Run outline_to_draft workflow.

Task: Generate ICML LaTeX manuscript from outline

Input outline: $PAPER_DIR/outline.md
KB folder: $KB_DIR
Output: $PAPER_DIR/
Format: icml

Steps:
1. Download ICML 2025 LaTeX template
2. Read outline and KB docs
3. Write main.tex with all sections
4. Write references.bib if citations found

Follow workflow spec: $WORKFLOWS/outline_to_draft/README.md
Safety: Read-only outline and KB, write-only paper folder, network allowed for template.
Log to: $LOG_DIR/$RUN_ID.log" \
  --model sonnet-4.5-thinking \
  --output-format stream-json \
  -f </dev/null > "$LOG_DIR/${RUN_ID}_step2_draft.jsonl" 2>&1

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [DONE] Step 2: Outline to Draft" | tee -a "$LOG_DIR/$RUN_ID.log"

# Step 3: Prepare Figures
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [START] Step 3: Prepare Figures" | tee -a "$LOG_DIR/$RUN_ID.log"

cursor-agent -p "Run prepare_figures workflow.

Task: Copy figures from source to paper folder

Outline: $PAPER_DIR/outline.md
Source figures: $SOURCE_CODE/figures/
Output: $PAPER_DIR/figures/

Copy figures listed in outline to paper folder.
Create figure_captions.txt with captions.

Follow workflow spec: $WORKFLOWS/prepare_figures/README.md
Safety: Read-only source, write-only paper folder figures.
Log to: $LOG_DIR/$RUN_ID.log" \
  --model sonnet-4.5-thinking \
  --output-format stream-json \
  -f </dev/null > "$LOG_DIR/${RUN_ID}_step3_figures.jsonl" 2>&1

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [DONE] Step 3: Prepare Figures" | tee -a "$LOG_DIR/$RUN_ID.log"

# Step 4: Compile LaTeX
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [START] Step 4: Compile LaTeX" | tee -a "$LOG_DIR/$RUN_ID.log"

cursor-agent -p "Run compile_latex workflow.

Task: Compile LaTeX to PDF

Paper folder: $PAPER_DIR
Main file: $PAPER_DIR/main.tex

Compile with pdflatex + bibtex sequence.
Fix common errors if needed.
Create compile.log with results.

Follow workflow spec: $WORKFLOWS/compile_latex/README.md
Safety: Can modify main.tex only to fix compilation errors.
Log to: $LOG_DIR/$RUN_ID.log" \
  --model sonnet-4.5-thinking \
  --output-format stream-json \
  -f </dev/null > "$LOG_DIR/${RUN_ID}_step4_compile.jsonl" 2>&1

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [$RUN_ID] [DONE] Step 4: Compile LaTeX" | tee -a "$LOG_DIR/$RUN_ID.log"

# Summary
echo ""
echo "=== Pipeline Complete ==="
echo "Run ID: $RUN_ID"
echo "Output folder: $PAPER_DIR"
echo "Logs: $LOG_DIR/$RUN_ID*.jsonl"
echo ""
echo "Files created:"
ls -lh "$PAPER_DIR"
echo ""
if [ -f "$PAPER_DIR/main.pdf" ]; then
  echo "✅ PDF generated: $PAPER_DIR/main.pdf"
  echo "   Size: $(ls -lh "$PAPER_DIR/main.pdf" | awk '{print $5}')"
  echo "   Pages: $(pdfinfo "$PAPER_DIR/main.pdf" 2>/dev/null | grep Pages | awk '{print $2}' || echo 'unknown')"
else
  echo "❌ PDF not generated - check logs"
fi

# Backup to GCS
echo ""
echo "=== Backing up to GCS ==="
BASE_DIR="/Users/cstein/code/activation_function_agent"
if [ -f "$BASE_DIR/backup_agent_runs.sh" ]; then
  "$BASE_DIR/backup_agent_runs.sh" 2>&1 | grep -E "===|\[2025|✅|⚠️|📊|💾|📄|📋|☁️"
  echo "Backup complete. Check: gs://ncl-agent-workflow-backups/activation_function_agent/"
else
  echo "⚠️  Backup script not found: $BASE_DIR/backup_agent_runs.sh"
fi

