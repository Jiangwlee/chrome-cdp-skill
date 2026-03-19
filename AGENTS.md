# AGENTS.md

This repository is maintained as a personal fork-based workspace and developed as a SOP skill platform built on top of Chrome CDP.

## Repository Setup

- Local path: `/home/bruce/Projects/chrome-cdp-skill`
- Fork remote: `origin = git@github.com:Jiangwlee/chrome-cdp-skill.git`
- Upstream remote: `upstream = https://github.com/pasky/chrome-cdp-skill.git`

## Project Positioning

- Keep this repository positioned as a `core + sites + tests` platform.
- `core` means shared Chrome CDP primitives and common SOP guidance.
- `sites` means website-specific workflows such as `reddit`, `taoguba`, and `x`.
- `tests` means smoke and workflow validation that agents can run repeatedly to detect broken skills.

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

## Repository Rules

- Do not repoint `origin` away from the personal fork.
- Do not remove `upstream`.
- Do not force-push `main` unless explicitly requested.
- Before any risky history rewrite, create a backup branch.

## Engineering Rules

- Prefer keeping general CDP behavior in the core layer instead of site-specific scripts.
- When adding a new site, add all of the following in the same change:
  - site scripts
  - site references
  - site tests
  - unified test-runner registration
- New site support is incomplete if it cannot be exercised by `skills/chrome-cdp/scripts/test.mjs`.
- Keep naming consistent with the site key used in scripts, references, tests, and test-runner registration.
- Keep `skills/chrome-cdp/scripts/cdp.mjs` in place as the stable forked core entrypoint.
- During the directory refactor, preserve working links and script entrypoints where possible until all references are updated.
- Prefer adding smoke tests that execute real workflow scripts and validate output structure, while marking missing browser prerequisites as setup issues rather than parser regressions.

## Target Layout

The target internal layout for `skills/chrome-cdp/` is:

```text
skills/chrome-cdp/
  SKILL.md
  scripts/
    cdp.mjs
    sites/
    test.mjs
  references/
    core/
    sites/
  tests/
    core/
    sites/
```
