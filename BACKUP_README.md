# Agent Workflow Backup System

## Current Status

✅ **Backup script created**: `backup_agent_runs.sh`  
✅ **Run IDs standardized**: `{workflow}_{YYYYMMDD}_{HHMMSS}`  
✅ **Logging structure**: All logs in `logs/{run_id}/`  
⚠️ **GCS auth needed**: Run `gcloud auth login` to enable cloud backups

---

## What Gets Backed Up

### 1. Run Logs
All directories in `logs/` containing:
- `orchestrator.log` - Human-readable decisions
- `orchestrator.jsonl` - Full agent output
- `status.json` - Current state
- `step_*.jsonl` - Individual step logs (if any)

### 2. Paper Outputs
Current `paper/` folder with:
- `main.pdf` - Generated paper
- `main.tex` - LaTeX source
- `figures/` - All figures
- `references.bib` - Bibliography

### 3. Run Manifest
JSON file with metadata about all runs:
- Run ID
- Status (completed/failed/unknown)
- Number of decisions
- Size
- GCS path

---

## Current Runs

```bash
logs/
├── paper_adaptive_20251026_212124/     # ✅ Adaptive orchestrator (SUCCESSFUL)
│   ├── orchestrator.log                # 10 decisions, completed
│   ├── orchestrator.jsonl              # 296K full output
│   └── status.json
└── paper_pipeline_20251026_205654/     # ⚠️ Rigid pipeline (INCOMPLETE)
    ├── orchestrator.log                # Fixed sequence
    ├── step1_outline.jsonl             # 111K
    ├── step2_draft.jsonl               # 203K
    ├── step3_figures.jsonl             # 169K
    └── step4_compile.jsonl             # 208K
```

---

## How to Use

### Manual Backup

```bash
cd /Users/cstein/code/activation_function_agent
./backup_agent_runs.sh
```

### Check Backup Log

```bash
tail -f backup.log
```

### One-Time GCS Setup

```bash
# Authenticate
gcloud auth login

# Verify access
gcloud storage ls gs://ncl-agent-workflow-backups/
```

---

## Where Backups Go

**GCS Bucket**: `gs://ncl-agent-workflow-backups/activation_function_agent/`

```
runs/
├── paper_adaptive_20251026_212124/
└── paper_pipeline_20251026_205654/

outputs/
├── paper_20251026_213540/              # Timestamped
└── paper_latest/                       # Always current

manifests/
└── run_manifest_20251026_213540.json
```

---

## Comparison Example

### Compare Rigid vs Adaptive Pipeline

```bash
# Download both runs
gcloud storage cp -r gs://ncl-agent-workflow-backups/activation_function_agent/runs/paper_pipeline_20251026_205654/ ./rigid/
gcloud storage cp -r gs://ncl-agent-workflow-backups/activation_function_agent/runs/paper_adaptive_20251026_212124/ ./adaptive/

# Compare orchestrator decisions
diff rigid/orchestrator.log adaptive/orchestrator.log

# Key difference:
# Rigid: No orchestrator.log (fixed steps)
# Adaptive: 10 decisions with evaluation loop
```

---

## Benefits

1. **Historical Record**: Track workflow evolution
2. **Debugging**: Compare failed vs successful runs
3. **Performance**: Analyze decision patterns
4. **Reproducibility**: Restore any run
5. **Safety**: Never lose work

---

## Next Steps

1. Run `gcloud auth login` to enable cloud backups
2. Backup runs manually after each workflow
3. (Optional) Set up automatic daily backups
4. Compare rigid vs adaptive pipelines from backups

---

## Documentation

Full docs: `/Users/cstein/vaults/projects/agents/workflows/meta/backup_and_versioning.md`

