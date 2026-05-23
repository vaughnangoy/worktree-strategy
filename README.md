# worktree-strategy

> Opinionated, PR-first git worktree workflow with a safe cross-repo auto-prune tool.

A small, repo-agnostic toolkit that encodes the following rules across every git repo on your machine:

- **Every feature, fix, or refactor lives in its own worktree.** The main worktree stays on `main` permanently.
- **Integration is always via Pull Request** — never a local `git merge` into main.
- **Push cadence is per-change**, not end-of-feature: every E2E-green change pushes to the open PR.
- **Worktree cleanup is automatic and conservative** — only PR-merged + clean + fully pushed worktrees are removed.

## What's in the box

| Path | Purpose |
|---|---|
| [`bin/prune-merged-worktrees`](./bin/prune-merged-worktrees) | Repo-agnostic bash script. Removes only worktrees whose branch has been PR-merged on origin. Leaves dirty, unpushed, PR-open, or divergent worktrees alone. |
| [`install.sh`](./install.sh) | Installs the binary to `~/.local/bin/` and registers the `git prune-worktrees` global alias. |
| [`POLICY.md`](./POLICY.md) | The full worktree + PR + push-cadence policy. Drop into any repo's docs as-is. |

## Install

```bash
git clone https://github.com/vaughnangoy/worktree-strategy.git
cd worktree-strategy
./install.sh
```

This:

1. Copies `bin/prune-merged-worktrees` to `~/.local/bin/` (creates the dir if missing).
2. Registers a global git alias: `git prune-worktrees`.
3. Warns if `~/.local/bin` is not on your `$PATH`.
4. Suggests installing `gh` if it's not already available.

## Usage

From inside **any worktree of any git repo**:

```bash
git prune-worktrees
```

Or call the binary directly with an explicit repo root:

```bash
prune-merged-worktrees /path/to/some/repo
```

### Recommended post-sync ritual

In your main worktree, every time you pull `main`:

```bash
git fetch --prune
git pull --ff-only origin main
git prune-worktrees
```

## Safety guarantees

The pruner will **only** remove a worktree when **all** of the following are true:

- The worktree is not the main worktree.
- The current branch is not the default branch.
- The working tree has no uncommitted, staged, or untracked changes.
- There are no unpushed commits.
- **Either** the PR for that branch reports `MERGED` on origin (via `gh`), **or** the branch is already an ancestor of `origin/<default-branch>` (ff-merge fallback when `gh` is unavailable).

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

The script **never** uses `git worktree remove --force` and **never** uses `git branch -D` on a branch that has not been confirmed merged via PR or ancestor-of-default.

## Requirements

- `git` ≥ 2.5 (worktree support).
- `bash` ≥ 4 (built-in arrays).
- `gh` (optional but recommended): full squash-merge detection. Without it, the script falls back to ancestor checks (catches only ff-merges).

## Why this exists

The default git worktree experience leaves cleanup as an exercise for the user, which means in practice nothing ever gets cleaned up — or worse, gets cleaned up too aggressively with `--force`. This tool encodes a single, conservative policy in one place and exposes it everywhere via `git prune-worktrees`.

See [`POLICY.md`](./POLICY.md) for the full workflow including PR cadence and push triggers.

## License

[MIT](./LICENSE)
