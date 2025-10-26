#!/bin/bash
# Agent Workflow Runs Backup Script
# Backs up agent logs, outputs, and run metadata to Google Cloud Storage
# Can be run manually or scheduled

set -e

# Configuration
PROJECT_NAME="activation_function_agent"
BASE_DIR="/Users/cstein/code/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
PAPER_DIR="${BASE_DIR}/paper"
GCS_BUCKET="gs://ncl-agent-workflow-backups/${PROJECT_NAME}"
LOG_FILE="${BASE_DIR}/backup.log"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Create log file directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting agent runs backup ==="

# Check if logs directory exists
if [ ! -d "$LOGS_DIR" ]; then
    log "❌ ERROR: Logs directory not found: $LOGS_DIR"
    exit 1
fi

# Count runs to backup
RUN_COUNT=$(find "$LOGS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
log "📊 Found $RUN_COUNT run directories to backup"

# Backup each run directory
for run_dir in "$LOGS_DIR"/*; do
    if [ -d "$run_dir" ]; then
        run_id=$(basename "$run_dir")
        
        # Skip if already backed up (check GCS)
        if gcloud storage ls "${GCS_BUCKET}/runs/${run_id}/" &>/dev/null; then
            log "⏭️  Skipping $run_id (already backed up)"
            continue
        fi
        
        log "💾 Backing up run: $run_id"
        
        # Upload run logs
        if gcloud storage cp -r "$run_dir" "${GCS_BUCKET}/runs/${run_id}/" 2>&1 | tee -a "$LOG_FILE"; then
            log "✅ Uploaded logs for $run_id"
        else
            log "⚠️  WARNING: Failed to upload logs for $run_id"
        fi
    fi
done

# Backup paper outputs (if they exist)
if [ -d "$PAPER_DIR" ]; then
    log "📄 Backing up paper outputs"
    
    # Create a timestamped backup of the paper folder
    if gcloud storage cp -r "$PAPER_DIR" "${GCS_BUCKET}/outputs/paper_${TIMESTAMP}/" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Uploaded paper outputs"
    else
        log "⚠️  WARNING: Failed to upload paper outputs"
    fi
    
    # Also create a "latest" copy
    if gcloud storage cp -r "$PAPER_DIR" "${GCS_BUCKET}/outputs/paper_latest/" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Updated latest paper outputs"
    else
        log "⚠️  WARNING: Failed to update latest paper outputs"
    fi
fi

# Create a run manifest
MANIFEST_FILE="${BASE_DIR}/run_manifest_${TIMESTAMP}.json"
cat > "$MANIFEST_FILE" << EOF
{
  "project": "$PROJECT_NAME",
  "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "runs": [
EOF

# Add each run to manifest
first=true
for run_dir in "$LOGS_DIR"/*; do
    if [ -d "$run_dir" ]; then
        run_id=$(basename "$run_dir")
        
        # Get run info from orchestrator.log if it exists
        if [ -f "$run_dir/orchestrator.log" ]; then
            first_line=$(head -1 "$run_dir/orchestrator.log")
            last_line=$(tail -1 "$run_dir/orchestrator.log")
            
            # Count decisions
            decision_count=$(grep -c "\[DECIDE\]" "$run_dir/orchestrator.log" || echo "0")
            
            # Check if completed
            if grep -q "DONE" "$run_dir/orchestrator.log"; then
                status="completed"
            elif grep -q "ABORT\|FAIL" "$run_dir/orchestrator.log"; then
                status="failed"
            else
                status="unknown"
            fi
        else
            first_line=""
            last_line=""
            decision_count=0
            status="unknown"
        fi
        
        # Get directory size
        size=$(du -sh "$run_dir" | cut -f1)
        
        # Add comma if not first
        if [ "$first" = false ]; then
            echo "," >> "$MANIFEST_FILE"
        fi
        first=false
        
        cat >> "$MANIFEST_FILE" << RUNEOF
    {
      "run_id": "$run_id",
      "status": "$status",
      "decisions": $decision_count,
      "size": "$size",
      "gcs_path": "${GCS_BUCKET}/runs/${run_id}/"
    }
RUNEOF
    fi
done

cat >> "$MANIFEST_FILE" << EOF

  ],
  "total_runs": $RUN_COUNT
}
EOF

# Upload manifest
log "📋 Uploading run manifest"
if gcloud storage cp "$MANIFEST_FILE" "${GCS_BUCKET}/manifests/" 2>&1 | tee -a "$LOG_FILE"; then
    log "✅ Uploaded manifest"
    rm "$MANIFEST_FILE"  # Clean up local copy
else
    log "⚠️  WARNING: Failed to upload manifest"
fi

# Final stats
GCS_RUN_COUNT=$(gcloud storage ls "${GCS_BUCKET}/runs/" 2>/dev/null | grep -c "/" || echo "0")
log "☁️  Total runs in GCS: $GCS_RUN_COUNT"

log "=== Backup complete ==="
log ""

exit 0

