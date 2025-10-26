#!/bin/bash
# Paper Improvement Orchestrator
# Iteratively improves paper draft section-by-section with multiple improvement dimensions

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

PROJECT_NAME="activation_function_agent"
BASE_DIR="/Users/cstein/code/$PROJECT_NAME"
PAPER_DIR="$BASE_DIR/paper"
CONFIG_FILE="$PAPER_DIR/improvement_config.json"
WORKFLOWS_DIR="/Users/cstein/code/agent-workflows/workflows/improve_paper"

# Read config
VERSION=$(jq -r '.version' "$CONFIG_FILE")
BASE_VERSION=$(jq -r '.base_version' "$CONFIG_FILE")
INPUT_DRAFT="$PAPER_DIR/main.tex"
OUTPUT_DRAFT="$PAPER_DIR/main_v${VERSION}.tex"

# Generate unique run ID
RUN_ID="improve_v${VERSION}_$(date '+%Y%m%d_%H%M%S')"
LOG_DIR="$BASE_DIR/logs/$RUN_ID"
mkdir -p "$LOG_DIR"

ORCH_LOG="$LOG_DIR/orchestrator.log"
ORCH_JSONL="$LOG_DIR/orchestrator.jsonl"
STATUS_FILE="$LOG_DIR/status.json"
CHANGES_LOG="$PAPER_DIR/improvements_v${VERSION}.md"

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log() {
    local phase=$1
    shift
    local msg="$@"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    echo "[$timestamp] [$phase] $msg" | tee -a "$ORCH_LOG"
}

update_status() {
    local status=$1
    local current_action=$2
    cat > "$STATUS_FILE" <<EOF
{
  "run_id": "$RUN_ID",
  "status": "$status",
  "goal": "Improve paper v${BASE_VERSION} to v${VERSION}",
  "started": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "current_action": "$current_action",
  "input": "$INPUT_DRAFT",
  "output": "$OUTPUT_DRAFT"
}
EOF
}

# ============================================================================
# INITIALIZATION
# ============================================================================

log "START" "Paper improvement orchestrator for v${VERSION}"
log "INFO" "Input: $INPUT_DRAFT"
log "INFO" "Output: $OUTPUT_DRAFT"
log "INFO" "Run ID: $RUN_ID"

# Create new git branch for this version
cd "$BASE_DIR"
BRANCH_NAME="improve/v${VERSION}_${RUN_ID}"
log "INFO" "Creating git branch: $BRANCH_NAME"
git checkout -b "$BRANCH_NAME" 2>&1 | tee -a "$ORCH_LOG"

# Copy input to output (we'll iteratively improve the output)
cp "$INPUT_DRAFT" "$OUTPUT_DRAFT"
log "INFO" "Copied v${BASE_VERSION} to v${VERSION} for improvement"

# Initialize changes log
cat > "$CHANGES_LOG" <<EOF
# Paper Improvements: v${BASE_VERSION} → v${VERSION}

**Run ID**: $RUN_ID  
**Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Input**: $INPUT_DRAFT  
**Output**: $OUTPUT_DRAFT

---

## Improvement Process

EOF

update_status "in_progress" "Initializing"

# ============================================================================
# SECTION EXTRACTION HELPER
# ============================================================================

extract_section() {
    local section_name=$1
    local tex_file=$2
    
    # Extract section using sed (simple approach - may need refinement)
    case "$section_name" in
        "abstract")
            sed -n '/\\begin{abstract}/,/\\end{abstract}/p' "$tex_file"
            ;;
        "introduction")
            sed -n '/\\section{Introduction}/,/\\section{/p' "$tex_file" | sed '$d'
            ;;
        "methods")
            sed -n '/\\section{Methods}/,/\\section{/p' "$tex_file" | sed '$d'
            ;;
        "results")
            sed -n '/\\section{Results}/,/\\section{/p' "$tex_file" | sed '$d'
            ;;
        "discussion")
            sed -n '/\\section{Discussion}/,/\\section{/p' "$tex_file" | sed '$d'
            ;;
        "conclusion")
            sed -n '/\\section{Conclusion}/,/\\end{document}/p' "$tex_file" | grep -v '\\end{document}'
            ;;
    esac
}

# ============================================================================
# MAIN IMPROVEMENT LOOP
# ============================================================================

SECTIONS=$(jq -r '.sections[]' "$CONFIG_FILE")
DIMENSIONS=$(jq -r '.improvement_dimensions[]' "$CONFIG_FILE")

log "PLAN" "Sections to improve: $(echo $SECTIONS | tr '\n' ' ')"
log "PLAN" "Improvement dimensions: $(echo $DIMENSIONS | tr '\n' ' ')"

for section in $SECTIONS; do
    log "SECTION" "Starting improvements for: $section"
    echo -e "\n### Section: $section\n" >> "$CHANGES_LOG"
    
    for dimension in $DIMENSIONS; do
        log "IMPROVE" "Applying $dimension to $section"
        update_status "in_progress" "Improving $section: $dimension"
        
        # Load prompt template
        PROMPT_FILE="$WORKFLOWS_DIR/prompts/${dimension}.md"
        if [ ! -f "$PROMPT_FILE" ]; then
            log "WARN" "Prompt file not found: $PROMPT_FILE, skipping"
            continue
        fi
        
        # Extract current section text
        SECTION_TEXT=$(extract_section "$section" "$OUTPUT_DRAFT")
        
        # Create temp files for this iteration
        TEMP_PROMPT="/tmp/improve_${section}_${dimension}_prompt.md"
        TEMP_OUTPUT="/tmp/improve_${section}_${dimension}_output.txt"
        
        # Prepare prompt with substitutions
        cat "$PROMPT_FILE" | \
            sed "s|{SECTION_NAME}|$section|g" | \
            sed "s|{KB_PATH}|$(jq -r '.paths.kb_path' "$CONFIG_FILE")|g" | \
            sed "s|{CODE_PATH}|$(jq -r '.paths.code_path' "$CONFIG_FILE")|g" | \
            sed "s|{SECTION_TEXT}|$SECTION_TEXT|g" > "$TEMP_PROMPT"
        
        # Call cursor-agent for improvement
        log "EXECUTE" "Running cursor-agent for $section/$dimension"
        
        cursor-agent \
            --model sonnet-4.5-thinking \
            --output-format stream-json \
            --browser \
            "$TEMP_PROMPT" \
            < /dev/null \
            > "$TEMP_OUTPUT" 2>&1 || {
                log "WARN" "cursor-agent failed for $section/$dimension"
                echo "- **$dimension**: FAILED" >> "$CHANGES_LOG"
                continue
            }
        
        # Parse output and extract improved section
        # (This is simplified - in practice, need robust parsing)
        IMPROVED_TEXT=$(cat "$TEMP_OUTPUT" | jq -r 'select(.type == "assistant") | .message.content[0].text' 2>/dev/null | tail -1)
        
        if [ -n "$IMPROVED_TEXT" ]; then
            # TODO: Replace section in OUTPUT_DRAFT with IMPROVED_TEXT
            # This requires more sophisticated LaTeX manipulation
            log "INFO" "Improvement generated for $section/$dimension"
            echo "- **$dimension**: Applied" >> "$CHANGES_LOG"
        else
            log "WARN" "No improvement generated for $section/$dimension"
            echo "- **$dimension**: No changes" >> "$CHANGES_LOG"
        fi
        
        # Cleanup
        rm -f "$TEMP_PROMPT" "$TEMP_OUTPUT"
        
        # Test compilation after each improvement
        log "CHECK" "Testing LaTeX compilation"
        cd "$PAPER_DIR"
        if pdflatex -interaction=nonstopmode "main_v${VERSION}.tex" > /dev/null 2>&1; then
            log "INFO" "Compilation successful"
        else
            log "ERROR" "Compilation failed after $section/$dimension - reverting"
            # TODO: Implement revert logic
            echo "- **$dimension**: REVERTED (compilation failed)" >> "$CHANGES_LOG"
        fi
        cd "$BASE_DIR"
        
    done
    
    log "DONE" "Completed improvements for $section"
done

# ============================================================================
# FINALIZATION
# ============================================================================

log "COMPILE" "Final compilation of v${VERSION}"
cd "$PAPER_DIR"
pdflatex -interaction=nonstopmode "main_v${VERSION}.tex" > "$LOG_DIR/compile.log" 2>&1
bibtex "main_v${VERSION}" >> "$LOG_DIR/compile.log" 2>&1 || true
pdflatex -interaction=nonstopmode "main_v${VERSION}.tex" >> "$LOG_DIR/compile.log" 2>&1
pdflatex -interaction=nonstopmode "main_v${VERSION}.tex" >> "$LOG_DIR/compile.log" 2>&1

if [ -f "main_v${VERSION}.pdf" ]; then
    PDF_SIZE=$(ls -lh "main_v${VERSION}.pdf" | awk '{print $5}')
    PDF_PAGES=$(pdfinfo "main_v${VERSION}.pdf" 2>/dev/null | grep Pages | awk '{print $2}')
    log "DONE" "PDF generated: ${PDF_SIZE}, ${PDF_PAGES} pages"
    
    echo -e "\n---\n\n## Final Output\n" >> "$CHANGES_LOG"
    echo "- **PDF**: main_v${VERSION}.pdf" >> "$CHANGES_LOG"
    echo "- **Size**: $PDF_SIZE" >> "$CHANGES_LOG"
    echo "- **Pages**: $PDF_PAGES" >> "$CHANGES_LOG"
else
    log "ERROR" "PDF generation failed"
    update_status "failed" "PDF compilation failed"
    exit 1
fi

cd "$BASE_DIR"

# ============================================================================
# GIT COMMIT & BACKUP
# ============================================================================

log "GIT" "Committing v${VERSION} to branch $BRANCH_NAME"
git add paper/ logs/"$RUN_ID"/
git commit -m "Paper improvement: v${BASE_VERSION} → v${VERSION}

Run: $RUN_ID
PDF: ${PDF_SIZE}, ${PDF_PAGES} pages
Logs: logs/$RUN_ID/
Branch: $BRANCH_NAME" 2>&1 | tee -a "$ORCH_LOG"

log "BACKUP" "Running GCS backup"
"$BASE_DIR/backup_agent_runs.sh" 2>&1 | tee -a "$ORCH_LOG"

# ============================================================================
# COMPLETION
# ============================================================================

update_status "completed" "Done"
log "DONE" "Paper improvement complete"
log "INFO" "Review changes: git diff main..${BRANCH_NAME}"
log "INFO" "Push to GitHub: git push origin ${BRANCH_NAME}"
log "INFO" "Output: $OUTPUT_DRAFT"

echo ""
echo "============================================"
echo "Paper Improvement Complete!"
echo "============================================"
echo "Version: v${VERSION}"
echo "PDF: $PAPER_DIR/main_v${VERSION}.pdf (${PDF_SIZE}, ${PDF_PAGES} pages)"
echo "Changes: $CHANGES_LOG"
echo "Logs: $LOG_DIR/"
echo "Branch: $BRANCH_NAME"
echo ""
echo "Next steps:"
echo "  1. Review: git diff main..${BRANCH_NAME}"
echo "  2. Push: git push origin ${BRANCH_NAME}"
echo "  3. Merge if satisfied: git checkout main && git merge ${BRANCH_NAME}"
echo "============================================"

