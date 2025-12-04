---
description: Prepare a new candidate branch for upstream PR contribution
---

You are helping prepare a PR branch for upstream contribution following the workflow in CLAUDE.md.

**Execute these steps automatically:**

0. **Request permissions upfront:**
   - Ask user for permission to execute all git operations needed:
     - `git status`, `git push origin develop`
     - `git checkout main`, `git fetch OPEN_SOURCE_UPSTREAM`, `git pull OPEN_SOURCE_UPSTREAM main`, `git pull`
     - `git push origin main`
     - `git ls-remote --heads OPEN_SOURCE_UPSTREAM`, `git branch -a`
     - `git checkout -b candidate-NNN-R main`
     - `git log main..develop` (to show what will be included)
     - `git merge --squash develop`
     - `git rm` commands to remove internal files
     - `git commit` with generated message
     - `git ls-files` verification commands
     - `git log --stat`, `git diff main..HEAD --stat`
   - Get approval before proceeding with any operations
   - Note: Commits that only touch internal files (.claude/, CLAUDE.md, etc.) are excluded from analysis

1. **Verify develop is clean and pushed:**
   - Check `git status` on develop branch
   - Ensure working tree is clean
   - Push any uncommitted changes to origin/develop

2. **Sync main with upstream (safe pull method):**
   - `git checkout main`
   - `git fetch OPEN_SOURCE_UPSTREAM`
   - `git pull OPEN_SOURCE_UPSTREAM main`
   - If pull fails (non-fast-forward or conflicts), **ABORT** and ask user to resolve manually
   - `git push origin main` (should be fast-forward)

3. **Auto-detect next candidate branch:**
   - Find max batch number from upstream: `git ls-remote --heads OPEN_SOURCE_UPSTREAM | grep 'candidate-'`
   - Find max batch number from local: `git branch -a | grep 'candidate-'`
   - Find the maximum batch number from local branches
   - **If that batch exists at upstream** → previous PR was merged, create new batch:
     - Create `candidate-{LOCAL_MAX+1}-1`
   - **If that batch does NOT exist at upstream** → previous PR is pending or damaged, redo:
     - Find highest revision for that batch (e.g., if `candidate-002-1` exists, next is `candidate-002-2`)
     - Create `candidate-{LOCAL_MAX}-{REV+1}`
   - Tell user which branch will be created and why (new delivery vs redo)

4. **Create and checkout the branch:**
   - `git checkout -b candidate-NNN-R main`

5. **Analyze and squash merge develop changes:**
   - Show commits that will be included: `git log main..develop --oneline`
   - Show summary of changes: `git diff main..develop --stat`
   - Execute: `git merge --squash develop`
   - This stages all changes from develop as a single commit

6. **Remove internal files before committing:**
   - Remove internal documentation and config files (from index AND disk):
     - `git rm -rf --ignore-unmatch .claude/` (entire directory)
     - `git rm -f --ignore-unmatch CLAUDE.md`
     - `git rm -f --ignore-unmatch poc/paneboard-poc.md`
     - `git rm -f --ignore-unmatch poc/REFACTORING_ROADMAP.md`
   - Note: Files are deleted from disk but will be restored when switching back to develop
   - **Verify removal**: `git ls-files | grep -E '(CLAUDE\.md|paneboard-poc\.md|REFACTORING_ROADMAP\.md|\.claude/)'`
   - **This should return nothing** - if files found, ERROR and stop
   - List all .md files to confirm only README.md present

7. **Generate and create feature rollup commit:**
   - Analyze all commits from `git log main..develop --format="%s%n%b"`
   - Filter out commits that only touch internal files (.claude/, CLAUDE.md, paneboard-poc.md, REFACTORING_ROADMAP.md)
   - Analyze staged changes with `git diff --cached --stat`
   - Draft a consolidated commit message that:
     - Summarizes the key features/fixes added since last merge
     - Groups related changes logically
     - Explains the "why" at a higher level than individual commits
     - Uses conventional commit format if appropriate
   - **Show the proposed commit message to user**
   - Create commit locally with: `git commit -m "message"`
   - **Do NOT include any attribution footer or mention of AI/Claude Code**

8. **Final review and amendment instructions:**
   - Show `git log -1 --stat` (the commit just created)
   - Show `git diff main..HEAD --stat`
   - **Display amendment instructions:**
     ```
     To amend the commit message before pushing:
     git commit --amend

     To push to origin when ready:
     git push -u origin candidate-NNN-R

     To return to development work:
     git checkout develop
     ```
   - **STOP** - user manually reviews and pushes when satisfied

**Important:**
- Be methodical and show output at each step
- Stop immediately if any errors occur
- The workflow should feel guided but safe
- User maintains control over commit selection and final push
