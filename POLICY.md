# Worktree + PR Policy

A complete, repo-agnostic workflow for feature development using git worktrees and pull requests. Drop this file into any repo's docs as-is; it makes no assumptions about language, framework, or directory layout beyond standard git conventions.

---

## 1. Policy

All feature work, fixes, and refactors MUST use **git worktrees** rather than checking out branches in-place. The default branch (`main` or `master`) lives in a **permanent worktree** and is never used as a scratch checkout.

### Layout

```
<repo-root>/                    ← permanent worktree on main
<repo-root>-worktrees/          ← sibling directory for all feature worktrees
    feature/<name>/
    fix/<name>/
    refactor/<name>/
```

### Rules

- **Never `git checkout <branch>` inside the main worktree.** It stays on the default branch permanently.
- **Every new feature, fix, or refactor → new worktree.**
  ```bash
  git worktree add ../<repo>-worktrees/feature/<name> -b feature/<name> main
  ```
- **Naming convention:** `feature/<short-desc>`, `fix/<short-desc>`, `refactor/<short-desc>`.
- **Worktree lifecycle:**
  1. **Create:** `git worktree add ../<repo>-worktrees/feature/<name> -b feature/<name> main`
  2. **Work, commit, push** the branch to `origin` from inside the worktree.
  3. **Integrate via Pull Request** (see §3) — NOT via local `git merge` into main.
  4. After the PR is merged on the remote, in the **main worktree**:
     `git fetch --prune && git pull --ff-only origin main && git prune-worktrees`
- **Parallel work:** because each task lives in its own worktree, multiple branches can be in flight concurrently without checkout conflicts.

### Verification before any change

1. Run `git worktree list` and confirm the main worktree is intact and on the default branch.
2. Confirm the current working directory is **not** the main worktree if any code is about to be modified.
3. If currently inside the main worktree and a code change is needed → create/switch to the appropriate feature worktree first.

---

## 2. In-worktree commit & push cadence (per-change PR updates)

The PR is opened **once** per feature (at the end of the first green-test cycle) and **kept open** as work continues. Every subsequent change that passes its test gate is pushed to the same feature branch, so the PR is always the live, reviewable surface for the feature — not a single end-of-feature dump.

### Push trigger

A push happens **if and only if** all of the following are true for the change just made:

1. Unit tests pass.
2. The relevant integration test passes.
3. End-to-end scenarios pass (recommend: 2 happy + 1 sad).
4. README / docs updated in the same change.
5. CHANGELOG `## [Unreleased]` bullet added.

If any of the above fail → **do not commit, do not push.** Root-cause + fix first.

### Steps (mandatory, in order)

From inside the feature worktree:

```bash
# 1. Stage only the files relevant to this change (never `git add -A`)
git add <files>

# 2. Conventional Commit — scope = sub-feature or module
git commit -m "feat(<scope>): <imperative summary>" -m "<body: what + why + tests added>"

# 3. Push to the feature branch on origin
git push origin feature/<name>
```

If this is the **first** push for the feature:

```bash
git push -u origin feature/<name>
gh pr create --base main --head feature/<name> \
  --title "<conventional-commit subject>" \
  --body-file docs/features/<YYYY-MM-DD>-<slug>.md \
  --draft   # open as draft until the whole feature is complete
```

If the PR already exists, the push automatically updates it — no extra command needed. CI re-runs on every push.

### Marking ready for review

When the final change of the feature is pushed:

```bash
gh pr ready    # flips draft → ready for review
```

### Hard rules for this cadence

- ❌ No commits without all 5 trigger conditions met.
- ❌ No pushes that bypass CI (no `--no-verify`, no force-push to a PR branch with prior pushes).
- ❌ No squashing locally before push — squash happens at PR-merge time, not before.
- ✅ Commit + push is the **only** way to checkpoint work. No "I'll push at the end."
- ✅ If the PR is open and CI is red, fix and push again — do **not** close + reopen.

---

## 3. Integration: PR-based merge (industry standard)

The community / industry consensus across GitHub Flow, GitLab Flow, Trunk-Based Development, and the Microsoft Engineering Playbook is the same: **never merge a feature branch directly into `main` from a local checkout. Always go through a Pull Request (or Merge Request).**

This holds even for solo repos. The PR gives you, at zero cost:

- A reviewable diff (self-review catches surprising amounts of bugs).
- A CI/checks gate that runs the same tests an external reviewer would expect.
- An immutable audit trail of why a change was merged, linked to issues/plans.
- A single canonical merge commit (squash or merge per repo policy) with the PR number in the subject — makes `git log` and `git bisect` orders of magnitude easier later.
- Atomic revert via "Revert PR" if the change misbehaves in production.

### Mandatory flow

From inside the feature worktree, after all unit + integration + e2e tests pass:

```bash
# 1. Push the branch
git push -u origin feature/<name>

# 2. Open the PR (gh CLI — install with `brew install gh` if missing)
gh pr create \
  --base main \
  --head feature/<name> \
  --title "<conventional-commit subject>" \
  --body-file docs/features/<YYYY-MM-DD>-<slug>.md
```

The PR body MUST be the completion report (or link to it). This gives any reviewer the full context inline.

### Review + merge

- **Solo work:** open the PR, walk through your own diff in the GitHub UI, wait for CI checks to go green, then merge.
- **Team work:** request at least one reviewer; do not self-approve.
- **Merge method:** prefer **squash-and-merge** for short-lived feature branches (one logical change → one commit on main). Use **merge commit** (no fast-forward) only when the individual commits on the branch tell a story worth preserving on main (rare).
- **Never** use rebase-and-merge for branches that have been pushed and reviewed — it loses the PR→commit linkage.
- **Branch protection:** `main` should require PR + passing CI + linear history. Configure via GitHub branch protection rules.

### Post-merge cleanup (mandatory order)

```bash
# Inside the main worktree
git fetch --prune
git pull --ff-only origin main

# Then run the cross-repo auto-prune (see §4)
git prune-worktrees
```

### Exceptions (narrow)

Direct local merge to `main` is acceptable ONLY for:

- Single-line typo fixes in docs (README, CHANGELOG comment).
- Reverting a clearly broken commit that is blocking other work.

Anything touching code, config, hooks, scripts, or behaviour MUST go through a PR — no exceptions.

---

## 4. Automatic worktree pruning (post-main-sync)

Whenever `main` is updated from `origin` in the main worktree, immediately run the prune routine. It removes only worktrees whose branches have been **merged via PR** on the remote, and leaves **all in-flight worktrees fully untouched** — including their unpushed commits, dirty trees, and untracked files.

### When it runs

Immediately after any of:

```bash
git pull --ff-only origin main
git fetch --prune && git merge --ff-only origin/main
```

### The tool

The pruner is shipped as a separate, repo-agnostic binary: see the [`worktree-strategy`](https://github.com/vaughnangoy/worktree-strategy) repo for installation and source.

After installation:

```bash
git prune-worktrees     # from inside any worktree of any repo
```

### Guarantees

| Worktree state | Action |
|---|---|
| PR merged on origin, clean, no unpushed commits | **removed** (worktree + local branch + remote branch) |
| PR open | left untouched |
| PR closed without merge | left untouched, flagged for manual review |
| No PR, branch is ancestor of `origin/<default>` | removed (worktree + local branch via safe `-d`) |
| No PR, branch is divergent | left untouched |
| Dirty (uncommitted, staged, or untracked files) | left untouched |
| Has unpushed commits | left untouched |
| No upstream configured | left untouched |

The routine **never** uses `git worktree remove --force` and **never** uses `git branch -D` on a branch that has not been confirmed merged via PR or already an ancestor of `origin/<default>`. **Any feature not fully merged via PR remains exactly as the agent left it.**

### Wiring

- The post-sync ritual in the main worktree is always:
  `git fetch --prune && git pull --ff-only origin main && git prune-worktrees`
- Treat `git prune-worktrees` as the second half of "sync main".
- Do **not** wire it into a git hook in `.git/hooks/` without explicit user consent (hooks run for unrelated `pull`s too, including third-party tools).

### Failure modes & fallback

- **`gh` not installed / not authenticated:** the script falls through to the `merge-base --is-ancestor` check, which is conservative (only prunes branches that ff-merged). Install `gh` (`brew install gh && gh auth login`) for full squash-merge detection.
- **Branch was force-pushed after merge:** treated as divergent, kept. Resolve manually.
- **Local uncommitted changes in a feature worktree:** kept (dirty check). Safe.
