# Activation Function Agent

Agent-driven workflow system for ML paper development.

---

## Quick Start

### Run Paper Pipeline (Adaptive)

```bash
cd /Users/cstein/code/activation_function_agent
./adaptive_paper_orchestrator.sh
```

This will:
1. Create paper outline from KB
2. Generate LaTeX manuscript
3. Prepare figures
4. Compile PDF
5. **Automatically backup to GCS**

### Check Results

```bash
# View PDF
open paper/main.pdf

# Check logs
ls -lh logs/paper_adaptive_*/

# View orchestrator decisions
cat logs/paper_adaptive_*/orchestrator.log
```

---

## Project Structure

```
/Users/cstein/code/activation_function_agent/
├── adaptive_paper_orchestrator.sh    # ✅ Adaptive decision loop (RECOMMENDED)
├── paper_pipeline_orchestrator.sh    # ⚠️  Rigid sequential pipeline (DEPRECATED)
├── backup_agent_runs.sh              # GCS backup script
├── paper/                             # Current output
│   ├── main.pdf
│   ├── main.tex
│   ├── figures/
│   └── references.bib
├── logs/                              # All workflow runs
│   ├── paper_adaptive_20251026_212124/
│   │   ├── orchestrator.log           # Human-readable decisions
│   │   ├── orchestrator.jsonl         # Full agent output
│   │   └── status.json               # Current state
│   └── paper_pipeline_20251026_205654/
│       └── step_*.jsonl
├── paper_old_*/                       # Previous versions
└── README.md                          # This file
```

---

## Workflows

### Adaptive Orchestrator (Recommended)

**Pattern**: Decision loop with evaluation

```
while not done:
    EVALUATE current state
    DECIDE next action
    EXECUTE action
    LOG result
```

**Advantages**:
- Adapts to problems
- Can fix issues mid-pipeline
- Verifies output quality
- No rigid step order

**Run**:
```bash
./adaptive_paper_orchestrator.sh
```

### Rigid Pipeline (Deprecated)

**Pattern**: Fixed sequence (1→2→3→4)

**Issues**:
- Can't adapt to problems
- No quality checks
- Fixed order causes issues (e.g., figures commented out)

**Use only for comparison/debugging**

---

## Backup System

### Automatic Backup

Both orchestrators automatically backup to GCS when complete:
- All run logs
- Paper outputs
- Run manifest with metadata

**GCS Location**: `gs://ncl-agent-workflow-backups/activation_function_agent/`

### Manual Backup

```bash
./backup_agent_runs.sh
```

### View Backups

```bash
# List all runs
gcloud storage ls gs://ncl-agent-workflow-backups/activation_function_agent/runs/

# Download a run
gcloud storage cp -r \
  gs://ncl-agent-workflow-backups/activation_function_agent/runs/paper_adaptive_20251026_212124/ \
  ./restored/

# View run manifest
gcloud storage cat \
  gs://ncl-agent-workflow-backups/activation_function_agent/manifests/run_manifest_*.json | jq .
```

---

## Run Identification

**Format**: `{workflow}_{YYYYMMDD}_{HHMMSS}`

**Examples**:
- `paper_adaptive_20251026_212124`
- `paper_pipeline_20251026_205654`

All logs for a run are in: `logs/{run_id}/`

---

## Comparison: Rigid vs Adaptive

### Rigid Pipeline (First Attempt)
- **Time**: 13 minutes
- **Result**: PDF with NO figures (all commented out)
- **Logs**: Scattered across multiple locations
- **Quality**: Incomplete

### Adaptive Orchestrator (Second Attempt)
- **Time**: 7 minutes
- **Result**: PDF with 8 figures, complete
- **Logs**: All in `logs/{run_id}/`
- **Quality**: Ready for review

**Key difference**: Adaptive orchestrator evaluates and adapts, rigid pipeline just executes blindly.

---

## Documentation

- **Backup System**: `BACKUP_README.md`
- **Workflow Specs**: `/Users/cstein/vaults/projects/agents/workflows/`
  - `kb_to_outline/README.md`
  - `outline_to_draft/README.md`
  - `prepare_figures/README.md`
  - `compile_latex/README.md`
- **Meta Docs**: `/Users/cstein/vaults/projects/agents/workflows/meta/`
  - `adaptive_orchestrator.md` - Pattern documentation
  - `logging_structure.md` - Log standards
  - `backup_and_versioning.md` - Backup system
  - `lessons_paper_pipeline.md` - Lessons learned

---

## Safety

- **Read-only**: `/Users/cstein/code/activation_function/` (source)
- **Read-only**: `/Users/cstein/vaults/projects/science/activation_function/` (KB)
- **Write-only**: `paper/`, `logs/`
- **No deletions** from source
- **All actions logged**

---

## Next Steps

1. Run adaptive orchestrator on other projects
2. Compare outputs across runs using GCS backups
3. Refine workflows based on lessons learned
4. Add more evaluation checks to orchestrator

---

**Created**: October 26, 2025  
**Status**: Production-ready  
**Pattern**: Adaptive orchestrator with automatic backup
