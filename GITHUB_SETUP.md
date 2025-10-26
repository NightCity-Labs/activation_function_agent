# GitHub Setup

## Create GitHub Repository

```bash
# Create repo using gh CLI
cd /Users/cstein/code/activation_function_agent
gh repo create activation_function_agent --public --source=.

# Configure git to use gh auth token (REQUIRED for NightCity-Labs org)
git config user.name "NightCity-Labs"
git config user.email "carlos.stein@nightcitylabs.ai"
git remote set-url origin https://$(gh auth token)@github.com/NightCity-Labs/activation_function_agent.git

# Push main branch
git push -u origin main

# Push all run branches
git push --all origin
```

**Note**: Using HTTPS with gh token in URL is required when SSH key is under different account (cstein06) than the org (NightCity-Labs).

## Workflow with GitHub

### After Each Run

The orchestrator automatically:
1. Creates branch: `run/{run_id}`
2. Commits results
3. Backs up to GCS

**To push to GitHub:**
```bash
git push origin run/paper_adaptive_20251026_212124
```

### Merging Successful Runs

```bash
# Review changes
git diff main..run/paper_adaptive_20251026_212124

# Merge to main
git checkout main
git merge run/paper_adaptive_20251026_212124

# Push to GitHub
git push origin main

# Delete local branch
git branch -d run/paper_adaptive_20251026_212124

# Delete remote branch
git push origin --delete run/paper_adaptive_20251026_212124
```

## Branch Naming Convention

- `main` - Stable, merged results
- `run/paper_adaptive_YYYYMMDD_HHMMSS` - Adaptive orchestrator runs
- `run/paper_pipeline_YYYYMMDD_HHMMSS` - Rigid pipeline runs (deprecated)
- `run/kb_creation_YYYYMMDD_HHMMSS` - KB creation runs

## What Gets Committed

### Included
- ✅ Paper outputs (`paper/`)
  - `main.pdf`
  - `main.tex`
  - `figures/`
  - `references.bib`
- ✅ Scripts (orchestrators, backup)
- ✅ Documentation (README, etc.)
- ✅ Infrastructure code (logger, status server)

### Excluded (via .gitignore)
- ❌ Run logs (`logs/*/`) - Backed up to GCS
- ❌ Temporary LaTeX files (`.aux`, `.log`, etc.)
- ❌ Old paper versions (`paper_old_*/`)
- ❌ SQLite databases
- ❌ Python cache

## Viewing History

### All runs
```bash
git log --oneline --graph --all
```

### Specific run
```bash
git show run/paper_adaptive_20251026_212124
```

### Compare runs
```bash
# See what changed between two runs
git diff run/paper_pipeline_20251026_205654..run/paper_adaptive_20251026_212124

# Just the PDF
git diff run/paper_pipeline_20251026_205654..run/paper_adaptive_20251026_212124 -- paper/main.pdf

# Just the LaTeX
git diff run/paper_pipeline_20251026_205654..run/paper_adaptive_20251026_212124 -- paper/main.tex
```

## Backup Strategy

**Three-tier backup:**

1. **Git (Local)**: All paper outputs and scripts
2. **GitHub (Remote)**: Same as git, plus collaboration
3. **GCS (Archive)**: Full logs, all runs, timestamped

**Why all three?**
- Git: Version control, diffs, history
- GitHub: Collaboration, remote backup, CI/CD
- GCS: Complete logs, long-term archive, comparison

## Best Practices

### Do
✅ Create new branch for each run (automatic)
✅ Commit after each run (automatic)
✅ Review changes before merging to main
✅ Push successful runs to GitHub
✅ Keep main branch clean (only merge good runs)

### Don't
❌ Commit directly to main (use branches)
❌ Force push (unless absolutely necessary)
❌ Delete run branches before backing up
❌ Commit large binary logs (use GCS)

## CI/CD Integration (Future)

### GitHub Actions Ideas

1. **On push to run/* branch:**
   - Validate PDF exists
   - Check PDF size/pages
   - Run LaTeX linter
   - Comment on commit with stats

2. **On merge to main:**
   - Archive to releases
   - Update documentation
   - Notify via Slack/Discord

3. **Scheduled:**
   - Weekly backup verification
   - Cleanup old branches
   - Generate comparison reports

## Example Workflow

```bash
# 1. Run orchestrator (creates branch + commits)
./adaptive_paper_orchestrator.sh

# Output:
# Git branch: run/paper_adaptive_20251026_212124
# ... workflow runs ...
# Committed to branch: run/paper_adaptive_20251026_212124

# 2. Review results
git show run/paper_adaptive_20251026_212124
open paper/main.pdf

# 3. Push to GitHub
git push origin run/paper_adaptive_20251026_212124

# 4. If good, merge to main
git checkout main
git merge run/paper_adaptive_20251026_212124
git push origin main

# 5. Clean up
git branch -d run/paper_adaptive_20251026_212124
git push origin --delete run/paper_adaptive_20251026_212124
```

---

**Created**: October 26, 2025  
**Status**: Ready for GitHub integration

