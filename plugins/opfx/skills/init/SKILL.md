---
name: init
description: Initialise a product repository for opfx — check prerequisites, interview the human for project-specific decisions (rubric, gates, models, knowledge), then scaffold OpenSpec, .factory/, AGENTS.md, GitHub labels and templates. Run once per product repo, from its root.
---

# /opfx:init

You are setting up a product repository so that opfx can run Issues through it. Work in the repository root the user is in. Never run this in the open-factory repository itself. Scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/`. Never run `find`, `fd`, `rg` or `grep -r` rooted at `/`, `~` or `/Users`: search only inside this repository and the plugin root; locate executables with `command -v`; run OpenSpec through `bash ${CLAUDE_PLUGIN_ROOT}/scripts/openspec.sh`.

## 1. Prerequisites (stop on any failure and tell the user how to fix it)
- `gh auth status` succeeds and the repo has a GitHub remote `origin`.
- `git remote show origin` — read `HEAD branch:`; this is the proposed `base_branch`.
- `node --version` is ≥ 20.19.
- `npx --yes @fission-ai/openspec@1.13.2 --version` prints `1.13.2`.
- `jq --version` works.
- If `openspec/` already exists, say so: scaffold keeps it and only rewrites `openspec/config.yaml`.

## 2. Interview
Ask one question at a time with AskUserQuestion; show the default and accept it on Enter. Collect answers into one JSON object (defaults in `${CLAUDE_PLUGIN_ROOT}/templates/config.json`):
1. `base_branch` — default: detected.
2. `language` — language for artifacts and GitHub comments (`ja` default).
3. Rubric — show `${CLAUDE_PLUGIN_ROOT}/templates/rubric.md`; explain the three sections (triage, rules with `=> requirement` suffixes, defaults) and the requirement vocabulary (`human_review:proposal|pr`, `design:required`, `human_check:<phase>:<text>`, `mergeable_by:human|handler`). Ask which rules to keep, change or add: when is human review mandatory, is design.md always required, is there a human check outside GitHub (a design review, a demo), who merges. Remember the answers; you edit `.factory/rubric.md` after scaffold (keep the `=>` grammar exactly).
4. `orchestration.workers`, `orchestration.review_parallel`, `orchestration.batch_size` — defaults 2 / 2 / 5.
5. `models.worker`, `models.reviewer`, `models.handler` — default opus / opus / opus (values: sonnet, opus, haiku, fable).
6. `review.max_rounds` (3 — reviewer runs per stage, the first review included), `review.stop_on` ([CRITICAL, QUESTION]), `review.contest_allowed` (1).
7. `gates.max_retries` (3).
8. `gates.test_command` — detect from `package.json` scripts (`npm test`), `Makefile`, `pyproject.toml`; confirm. `gates.lint_command` — optional.
9. Scenario ↔ test mapping check — default off; if on, run `chmod +x .factory/evals/scenario-tests.sh` after scaffold.
10. `escalation.on` — default all of a..f (a worker stuck, b spec judgment, c contradiction in the source of truth, d removing a Scenario, e archive refusal needing a plan change, f two PRs changing the same requirement).
11. `labels` — show the default colors; accept or edit.
12. `knowledge` — free text: stack, conventions, places not to touch, naming. Goes to `AGENTS.md` and `openspec/config.yaml` context.
13. `gates.wait_ci` — default true when `.github/workflows/` exists, else false.
14. `design.docs_dir` — where the project keeps its design documents (default `docs/design`). Ask whether the project draws screens and with which tool; opfx names no tool, so the tool, its file or workspace, the placement and naming rules and how to read drawings back go into `knowledge` (AGENTS.md) and into documents under `design.docs_dir` that the project writes itself.

## 3. Scaffold
Write the answers to a temp file and run:
```
OPFX_ROOT="$PWD" bash "${CLAUDE_PLUGIN_ROOT}/scripts/scaffold.sh" /tmp/opfx-answers.json
```
Read the JSON result. Edit `.factory/rubric.md` per the interview. Show a table of created / skipped files and the 8 labels.

## 4. Commit
`git add .factory AGENTS.md docs openspec .github && git commit -m "opfx: initialise product repo"`. Do not push. Tell the user: run `/opfx:supervisor` to start.
