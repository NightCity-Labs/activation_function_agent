# Activation Function Agent

Agent-driven paper pipeline for the activation function learning project.

**Uses**: [agent-workflows](https://github.com/NightCity-Labs/agent-workflows) - General workflow system

---

## Quick Start

```bash
./adaptive_paper_orchestrator.sh
```

This will:
1. Create new git branch (`run/{run_id}`)
2. Generate ICML paper from KB
3. Commit results
4. Backup to GCS

---

## Project Structure

```
activation_function_agent/
├── adaptive_paper_orchestrator.sh    # Project-specific orchestrator
├── paper/                             # Generated paper outputs
├── logs/                              # Run logs (backed up to GCS)
└── README.md
```

---

## Configuration

**Source**: `/Users/cstein/code/activation_function/`  
**KB**: `/Users/cstein/vaults/projects/science/activation_function/`  
**Workflows**: Uses [agent-workflows](https://github.com/NightCity-Labs/agent-workflows)  
**Format**: ICML 2025

---

## Workflows Used

From [agent-workflows](https://github.com/NightCity-Labs/agent-workflows):
- `kb_to_outline` - Create paper structure
- `outline_to_draft` - Generate LaTeX
- `prepare_figures` - Organize figures
- `compile_latex` - Build PDF

---

## Git Workflow

Each run creates branch: `run/{run_id}`

```bash
# View changes
git diff main..run/paper_adaptive_20251026_212124

# Merge if good
git checkout main && git merge run/paper_adaptive_20251026_212124
```

---

## Backup

- **Git**: Paper outputs, version control
- **GitHub**: https://github.com/NightCity-Labs/activation_function_agent
- **GCS**: `gs://ncl-agent-workflow-backups/activation_function_agent/`

---

## Results

### Successful Runs
- `paper_adaptive_20251026_212124` - ✅ 567KB PDF, 7 pages, 8 figures

### Failed Runs
- `paper_pipeline_20251026_205654` - ⚠️ Rigid pipeline, figures commented out

---

**Project**: Activation Function Learning  
**Paper**: ICML 2025 submission  
**System**: [agent-workflows](https://github.com/NightCity-Labs/agent-workflows)
