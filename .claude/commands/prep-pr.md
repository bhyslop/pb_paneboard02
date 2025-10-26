---
description: Prepare a new candidate branch for upstream PR contribution
---

You are helping prepare a PR branch for upstream contribution following the workflow in CLAUDE.md.

**Execute these steps automatically:**

1. **Verify develop is clean and pushed:**
   - Check `git status` on develop branch
   - Ensure working tree is clean
   - Push any uncommitted changes to origin/develop

2. **Sync main with upstream:**
   - `git fetch OPEN_SOURCE_UPSTREAM`
   - `git branch -f main OPEN_SOURCE_UPSTREAM/main`
   - `git push origin main --force`

3. **Auto-detect next candidate branch:**
   - Find max batch number from upstream: `git ls-remote --heads OPEN_SOURCE_UPSTREAM | grep 'candidate-'`
   - Find max batch number from local: `git branch -a | grep 'candidate-'`
   - **If local max > upstream max:**
     - Find highest revision for that batch (e.g., `candidate-002-3`)
     - Create `candidate-XXX-{N+1}` (same batch, increment revision)
   - **Else:**
     - Create `candidate-{MAX+1}-1` (new batch, revision 1)
   - Tell user which branch will be created

4. **Create and checkout the branch:**
   - `git checkout -b candidate-NNN-R main`

5. **Show available commits from develop:**
   - `git log develop --oneline -30`
   - Ask user which commits to cherry-pick (they can specify SHAs or a range)

6. **Cherry-pick selected commits:**
   - Execute `git cherry-pick` with user's selections
   - Handle conflicts if they occur

7. **Verify no internal files present:**
   - `git ls-files | grep -E '(CLAUDE\.md|paneboard-poc\.md|REFACTORING_ROADMAP\.md|\.claude/)'`
   - **This should return nothing** - if files found, ERROR and stop
   - List all .md files to confirm only README.md present

8. **Final review and stop:**
   - Show `git log --stat` for the new branch
   - Show `git diff main..HEAD --stat`
   - **STOP** - tell user to manually review and then push with:
     - `git push -u origin candidate-NNN-R`

**Important:**
- Be methodical and show output at each step
- Stop immediately if any errors occur
- The workflow should feel guided but safe
- User maintains control over commit selection and final push
