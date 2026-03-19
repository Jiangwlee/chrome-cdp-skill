# AGENTS.md

This repository is maintained as a personal fork-based workspace.

## Repository Setup

- Local path: `/home/bruce/Projects/chrome-cdp-skill`
- Fork remote: `origin = git@github.com:Jiangwlee/chrome-cdp-skill.git`
- Upstream remote: `upstream = https://github.com/pasky/chrome-cdp-skill.git`

## Branch Strategy

- `main` tracks the fork's `origin/main` and should stay close to upstream.
- `bruce/custom` is the long-lived branch for personalized development.
- Feature work should normally branch from `bruce/custom`, unless there is a clear reason to work directly on it.

## Sync Workflow

Update local `main` from upstream:

```bash
git checkout main
git fetch upstream
git rebase upstream/main
git push origin main
```

Rebase personalized work onto the updated `main`:

```bash
git checkout bruce/custom
git rebase main
git push --force-with-lease origin bruce/custom
```

## Agent Rules

- Do not repoint `origin` away from the personal fork.
- Do not remove `upstream`.
- Do not force-push `main` unless explicitly requested.
- Prefer keeping upstream sync work on `main` and custom work on `bruce/custom`.
- Before any risky history rewrite, create a backup branch.
