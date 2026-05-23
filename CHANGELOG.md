# Changelog

All notable changes to this project are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [Unreleased]

### Added
- Initial extraction from the SecondBrain repo.
- `bin/prune-merged-worktrees`: repo-agnostic bash script that removes only PR-merged + clean + fully pushed worktrees, with `gh` for squash-merge detection and `merge-base --is-ancestor` as a conservative fallback.
- `install.sh`: installs the binary into `~/.local/bin/` and registers `git prune-worktrees` as a global git alias.
- `POLICY.md`: full worktree + PR + push-cadence policy, ready to drop into any repo.
- `README.md`, `LICENSE` (MIT).
