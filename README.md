# Activation Function Agent

Agent-driven research workflow for activation function experiments and paper generation.

---

## Quick Start

```bash
# Generate initial paper draft (v1)
./adaptive_paper_orchestrator.sh

# Improve paper iteratively (v2, v3, ...)
./improve_paper_orchestrator.sh
```

---

## Project Structure

```
activation_function_agent/
├── paper/                          # Paper outputs
│   ├── main.tex                    # v1 draft
│   ├── main_v2.tex                 # v2 improved
│   ├── main.pdf / main_v2.pdf      # Compiled PDFs
│   ├── figures/                    # Paper figures
│   ├── references/                 # Reference papers for quality benchmarking
│   ├── improvement_config.json     # Improvement workflow config
│   └── improvements_v2.md          # Change log for v2
├── logs/                           # Workflow run logs
│   ├── paper_adaptive_YYYYMMDD_HHMMSS/  # v1 generation logs
│   └── improve_v2_YYYYMMDD_HHMMSS/      # v2 improvement logs
├── adaptive_paper_orchestrator.sh  # Generate initial draft
├── improve_paper_orchestrator.sh   # Iterative improvement
└── backup_agent_runs.sh            # GCS backup script
```

---

## Workflows

### 1. Initial Paper Generation (v1)

**Script**: `adaptive_paper_orchestrator.sh`

Adaptive decision loop that:
- Reads KB documentation
- Creates outline
- Generates LaTeX draft
- Prepares figures
- Compiles to PDF
- Evaluates and fixes issues dynamically

**Output**: `paper/main.tex`, `paper/main.pdf`

### 2. Paper Improvement (v2+)

**Script**: `improve_paper_orchestrator.sh`

Section-by-section iterative improvement with multiple dimensions:
- **Align with sources**: Verify claims against KB/code/results
- **Sharpen arguments**: Strengthen logic and precision
- **Improve style**: Clarity, conciseness, technical writing
- **Restructure**: Better organization and flow
- **Check consistency**: Notation, terminology, cross-references

**Configuration**: `paper/improvement_config.json`

**Reference Papers**: `paper/references/` (Swish, GELU, Mish papers for benchmarking)

**Output**: `paper/main_v2.tex`, `paper/main_v2.pdf`, `paper/improvements_v2.md`

---

## Versioning & Backup

### Git Branches

- `main`: Stable versions
- `run/paper_adaptive_YYYYMMDD_HHMMSS`: v1 generation runs
- `improve/v2_YYYYMMDD_HHMMSS`: v2 improvement runs

Each run creates a dedicated branch for isolation and review.

### Google Cloud Storage

All runs backed up to: `gs://ncl-agent-workflow-backups/activation_function_agent/`

- `runs/{run_id}/`: Complete logs for each run
- `outputs/paper_latest/`: Latest paper outputs
- `outputs/paper_{timestamp}/`: Timestamped paper versions
- `manifests/`: Run metadata and index

### Workflow Comparison

```bash
# Compare v1 and v2
git diff run/paper_adaptive_20251026_212124..improve/v2_20251026_221500 -- paper/

# View all runs
git log --oneline --graph --all

# Check GCS backups
gcloud storage ls gs://ncl-agent-workflow-backups/activation_function_agent/runs/
```

---

## Source Data

- **KB Documentation**: `/Users/cstein/vaults/projects/science/activation_function/`
- **Source Code**: `/Users/cstein/code/activation_function/` (read-only)
- **Experiments**: wandb project `activation_function` (read-only)

---

## Safety

- Source project (`activation_function/`) is **read-only**
- All agent writes go to `activation_function_agent/`
- Automatic git branching prevents main branch corruption
- GCS backup for disaster recovery
- Compilation tested after each improvement

---

## General Workflow System

This project uses the general agent workflow system: https://github.com/NightCity-Labs/agent-workflows

See that repo for:
- Workflow patterns (adaptive orchestrator, KB creation, etc.)
- Infrastructure code (logging, status server, backup)
- Execution safety policies

---

**Last Updated**: October 26, 2025
