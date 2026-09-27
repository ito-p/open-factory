# open-factory

A software factory harness, distributed as a Claude Code plugin.

open-factory holds only the harness: the agents, skills, scripts and templates that turn a GitHub Issue into a merged pull request through specification, review, implementation and gates. Products live in their own repositories. Humans steer through GitHub: they write requests as Issues, answer the questions the factory cannot decide, and review plans and pull requests where the project's rules say a human must.

The plugin is `opfx`, in the marketplace `open-factory`. Specifications are managed with [OpenSpec](https://github.com/Fission-AI/OpenSpec) 1.13.2 (pinned); opfx borrows its templates and CLI and adds the knowledge, evals, agents, trace and pipeline on top.

## How a change flows

One Issue becomes one OpenSpec change, on its own branch and worktree.

```
Issue (opfx:queued)
  └─ worker: propose ─ proposal.md, spec delta, design.md (when required), tasks.md
       gate 1  validate.sh   OpenSpec strict validation of the delta
       draft PR              the plan is pushed so humans can read it on GitHub
       R1      reviewer      plan review: findings (CRITICAL / WARNING / SUGGESTION / QUESTION)
                             + a rubric-verdict table; the handler fixes WARNING/CRITICAL
                             through the worker, escalates QUESTIONs, and asks a human
                             when the rubric says human_review:proposal
  └─ worker: apply ─ implements tasks.md, verifying each task as written
       gate 2  eval.sh       test command, lint command, then every executable in .factory/evals
  └─ worker: archive ─ archive.sh refuses open tasks, then merges the delta into openspec/specs
       PR ready              body follows the PR template; Closes #<issue>
  └─ handler: gate 3  check-pr.sh   merge origin/<base> into the PR, union-merge spec conflicts
                                    on different requirements, refuse same-requirement conflicts,
                                    validate specs and archived changes, push, wait for CI
       R2      reviewer      implementation review against the delta and the tasks
       merge                 the handler merges when the rubric allows (mergeable_by:handler),
                             otherwise a human reviews or merges on GitHub
  └─ handler: usage and summary comments on the Issue (opfx:done)
```

Anything the pipeline cannot decide is escalated to the human through the supervisor: spec judgments (kinds a–f), a plan or PR review request, a merge request, or a follow-up list of deferred WARNINGs.

## Intake

Requests do not have to come from the human's chat. Anyone or anything, a person, a monitoring bot, another agent, can open an Issue with the label `opfx:intake` in free form; a production error uses the incident Issue form, which adds `opfx:incident`. The supervisor picks these up on startup or on request, checks for duplicates, rewrites each one into the four sections (request, acceptance criteria, assumptions, out of scope) with the original quoted, asks the reporter or the human for anything missing, and moves it to `opfx:queued` once the human confirms. Intake only queues: nothing runs until the human names the Issue. An incident keeps its label through the run, and the rubric's `[incident]` rule sends its PR to a human review before merge.

## Roles and topology

| Role | What it is | What it does |
|---|---|---|
| supervisor | the only human-facing session (`/opfx:supervisor`) | writes Issues from the human's words, dispatches the Issues the human names, relays worker reports, brings escalations to the human, records answers on the Issue |
| handler | sub agent of the supervisor | runs one batch: starts workers (N in parallel), runs reviewers, applies the rubric, runs gate 3, merges, posts usage |
| worker | sub agent of the handler, one per Issue | propose → apply → archive → PR inside its own worktree; hands back at phase boundaries and resumes when messaged |
| reviewer | sub agent of the handler, read-only | R1 (plan) and R2 (implementation) reviews with a rubric verdict |

Hand-offs are sub agent starts, hand-backs and messages. The state of record is GitHub: the `opfx:*` label on the Issue and the trace comments. Nothing else is persisted, so a killed session resumes from the labels and the worktree.

## What the human decides

Project-specific judgment lives in two files the human writes at `/opfx:init` and edits any time.

`.factory/rubric.md` is read by the reviewer as prose and by a script as data:

```
## triage
- CRITICAL: ...   WARNING: ...   SUGGESTION: ...   QUESTION: ...

## rules
- [api] any change that adds, removes or alters an HTTP API => human_review:pr, design:required
- [ui]  any change that alters a screen or a transition        => design:required

## defaults
- no-match    => mergeable_by:handler
- undecidable => human_review:pr, mergeable_by:human
```

Requirement vocabulary: `human_review:proposal|pr`, `design:required`, `human_check:<phase>:<text>`, `mergeable_by:human|handler`. The reviewer returns one verdict per rule (`match`, `no-match`, `undecidable`); `rubric-parse.sh` turns the table into decisions, falling to the defaults when rules do not decide.

`.factory/config.json` holds the numbers: base branch, language, workers and review parallelism, models per role, review rounds and what stops a review, gate retries and commands, CI waiting, escalation kinds, label colors, and where the project keeps its design documents.

opfx names no design tool. If the product draws screens, its `AGENTS.md` and design documents say which tool, where its files are, how to place and name things and how to read them back; the worker follows those rules and the reviewer checks against them.

## Repository layout

```
.claude-plugin/marketplace.json      marketplace `open-factory`
plugins/opfx/
  .claude-plugin/plugin.json         plugin `opfx`
  agents/                            handler.md  worker.md  reviewer.md
  skills/                            init/SKILL.md  supervisor/SKILL.md
  scripts/                           the machine parts (see below) and their tests
  templates/                         what /opfx:init writes into a product repo
  tests/checklist.sh                 pins the phrases the agent contracts rely on
  pricing.json                       API prices used by usage.sh
.github/workflows/test.yml           runs the script tests and the checklist
```

### Scripts

Every script prints one JSON object on stdout and exits 0 (green), 1 (red) or 2 (usage error). They run from the product repo (`OPFX_ROOT`) and never touch git except where stated.

| Script | Purpose |
|---|---|
| `validate.sh <change>` | gate 1: OpenSpec strict validation; ERROR and WARNING are red |
| `eval.sh <change>` | gate 2: test command, lint command, then every executable in `.factory/evals/` |
| `archive.sh <change>` | refuses open tasks, then archives through the pinned OpenSpec CLI |
| `check-pr.sh <pr>` | gate 3: merge the base branch into the PR checkout, resolve or refuse spec conflicts, validate, push, wait for CI |
| `trace.sh issue\|pr <n> <kind> …` | the only trace: one GitHub comment per event (phase, gate, review, rubric, answer, agent, usage, summary) |
| `usage.sh …` | totals a sub agent's or session's tokens from the transcript and estimates the API price, per phase when asked |
| `rubric-parse.sh <review>` | turns the reviewer's rubric-verdict table into decisions |
| `pr-review.sh <pr>` | reads the human's GitHub review of a PR (latest review per author decides; line comments carried) |
| `scaffold.sh <answers.json>` | sets up a product repo from the init answers |
| `labels.sh` | creates the `opfx:*` labels with the configured colors |
| `openspec.sh …` | runs the pinned OpenSpec CLI; agents never search for a binary |
| `render.mjs` | fills `{{PLACEHOLDERS}}` in templates |

### Templates

`config.json` (defaults), `rubric.md`, `AGENTS.md`, `openspec-config.yaml`, `issue_template.yml`, `incident_template.yml`, `pull_request_template.md`, and `evals/` (a README and an optional Scenario-to-test check).

## What a product repository gets

`/opfx:init` checks prerequisites, interviews the human, and writes:

```
.factory/config.json          numbers
.factory/rubric.md            judgment
.factory/evals/               project evals (executables run by gate 2)
AGENTS.md                     knowledge for every agent (stack, conventions, design tool, places not to touch)
openspec/                     OpenSpec: specs (source of truth), changes, config
.github/ISSUE_TEMPLATE/opfx.yml
.github/pull_request_template.md
labels                        opfx:intake incident queued proposed review approved pr blocked done follow-up
```

Conventions: change `<issue>-<kebab-title>`, branch `factory/<change>`, worktree `../<repo>-wt/<change>`, trace comments `<kind> | <change> | … | <timestamp>`.

## Install and use

1. In Claude Code: `/plugin marketplace add ito-p/open-factory`, then `/plugin install opfx@open-factory`. From a checkout: `claude --plugin-dir <path>/open-factory/plugins/opfx`.
2. In the product repository root: `/opfx:init`.
3. `/opfx:supervisor`. Describe a request and the supervisor drafts an Issue; say `run #12` and the handler takes it to a merged PR, asking you only what the rubric and the escalation kinds say it must.

Prerequisites: `gh` (authenticated), Node ≥ 20.19, `jq`, and network access for `npx @fission-ai/openspec@1.13.2`.

## Development

```
bash plugins/opfx/scripts/tests/run.sh    # script tests against a throwaway repo with a gh stub
bash plugins/opfx/tests/checklist.sh      # instruction checklist (script references, OpenSpec verbs, contract phrases, no tool names)
```

## Principles

- The harness holds no product and names no design tool; products and their tools live in their repositories.
- Everything a human must decide is written down once, in the rubric and the config, and read by machines from there.
- The trace is on GitHub only, in the Issue and PR comments; sessions can die and resume.
- Agents follow hard rules: work only in their worktree, never edit the source of truth by hand, never touch policy files, never search outside the repository.

## License

MIT
