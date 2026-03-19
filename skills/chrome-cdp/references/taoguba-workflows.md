# Taoguba Workflows

This file describes the repeatable `tgb.cn` / Taoguba workflows bundled with
the skill. Input is either a time-windowed list task or a single Taoguba post
URL. Output is structured JSON from the helper scripts under `../scripts/`.
Public entrypoints are `taoguba-jinghua.sh`, `taoguba-following.sh`, and
`taoguba-open-post.sh`.

## Scope

- Extract `jinghua` posts from the last 24 hours by default.
- Extract followed-content updates from the last 12 hours by default.
- Open one Taoguba post and return the main post body.
- Do not expand pagination or follow reply floors.

## Script entrypoints

- [../scripts/taoguba-jinghua.sh](../scripts/taoguba-jinghua.sh)
  Inputs: optional hour window, optional result limit, optional target prefix.
  Output: JSON array of recent `jinghua` posts with title, author, post time,
  reply time, stats, and URL.
- [../scripts/taoguba-following.sh](../scripts/taoguba-following.sh)
  Inputs: optional hour window, optional result limit, optional target prefix.
  Output: JSON array of recent followed-content updates with actor, update
  time, action, text, source post title, and URL.
- [../scripts/taoguba-open-post.sh](../scripts/taoguba-open-post.sh)
  Inputs: one Taoguba post URL, optional target prefix.
  Output: JSON object with title, author, publish time, stats, text, and URL.

## Workflow notes

- `jinghua` time strings are month-day plus clock time, so the workflow assumes
  the current year and filters against the current browser time.
- Followed-content updates already expose full timestamps and action labels like
  `跟帖了` or `发布了`.
- Taoguba pages can keep loading after the visible content is ready, so the
  scripts use tolerant navigation plus explicit waits on visible text.
