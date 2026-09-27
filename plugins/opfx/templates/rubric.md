# rubric

The reviewer reads this file. Text is for the reviewer; the part after `=>` is read by a script.

## triage
- CRITICAL: proceeding would break something, or the human's intent is not carried. R1: an Issue requirement or acceptance criterion has no Scenario in the delta; the delta contradicts the source of truth; MODIFIED/ADDED misuse that archive would refuse. R2: a Scenario has no passing test; code disagrees with the delta; a task is `[x]` but not done.
- WARNING: nothing breaks, but the intent is carried weakly. R1: a Scenario lacks boundary values; a design decision lists no alternative; a task states no way to verify. R2: a design decision is not visible in code; names differ between docs and code.
- SUGGESTION: an improvement that this run does not need.
- QUESTION: a spec judgment neither reviewer nor worker can make. Escalate immediately.

## rules
- [ui] any change that adds, removes or alters a screen, a state of a screen or a transition between screens => design:required
- [api] any change that adds, removes or alters an HTTP API (routes, request or response shapes, status codes) => human_review:pr, design:required
- [db] any change that adds or alters the database schema (tables, columns, indexes, migrations) => human_review:pr, design:required
- [behavior-change] the change adds, removes or alters a requirement or a Scenario of the source of truth (observable behavior) => human_review:pr
- [incident] the Issue carries the label opfx:incident (a production error or incident) => human_review:pr
- [new-capability-design] the change creates a new capability => design:required
- [docs-only] the change has skip_specs and touches only docs/ => mergeable_by:handler

## defaults
The no-match line also fills mergeable_by when matched rules leave it unset. Keep comments off the `=>` lines: the parser reads the whole rest of the line.

- no-match => mergeable_by:human
- undecidable => human_review:pr, mergeable_by:human
