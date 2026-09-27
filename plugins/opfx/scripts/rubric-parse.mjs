#!/usr/bin/env node
// rubric-parse.mjs — read the reviewer's "## rubric-verdict" table, apply the rubric's "=> requirement" suffixes,
// and fall to the human on any doubt (missing table, unknown id, undecidable verdict, malformed line).
import { readFileSync, existsSync } from "node:fs";

const args = process.argv.slice(2); let file = null, rubric = null;
for (let i = 0; i < args.length; i++) { if (args[i] === "--rubric") rubric = args[++i]; else file = args[i]; }
rubric ??= `${process.env.OPFX_ROOT || process.cwd()}/.factory/rubric.md`;
if (!file || !existsSync(file) || !existsSync(rubric)) { process.stderr.write("usage: rubric-parse.sh <reviewer-output> [--rubric <path>]\n"); process.exit(2); }

const out = { human_review: [], design_required: false, human_checks: [], mergeable_by: "human", matched: [], undecidable: [], unknown: [], error: null };

// rules and defaults from the rubric
const rules = new Map(), defaults = { "no-match": [], undecidable: [] }; let section = "";
for (const raw of readFileSync(rubric, "utf8").split("\n")) {
  const l = raw.trim();
  if (l.startsWith("## ")) { section = l.slice(3).trim().toLowerCase(); continue; }
  const m = l.match(/^- \[([a-z0-9-]+)\] .*=> (.+)$/);
  const dm = l.match(/^- (no-match|undecidable) => (.+)$/);
  if (section === "rules" && m) rules.set(m[1], m[2].split(",").map(s => s.trim()).filter(Boolean));
  if (section === "defaults" && dm) defaults[dm[1]] = dm[2].split(",").map(s => s.trim()).filter(Boolean);
}

// verdict table from the reviewer's output
const text = readFileSync(file, "utf8"); const idx = text.indexOf("## rubric-verdict");
const verdicts = new Map();
if (idx < 0) out.error = "no rubric-verdict table";
else for (const l of text.slice(idx).split("\n").slice(1)) {
  const t = l.trim();
  if (!t.startsWith("|")) { if (verdicts.size) break; continue; }
  const cells = t.split("|").map(s => s.trim()).filter((_, i, a) => i > 0 && i < a.length - 1);
  if (cells.length < 2 || cells[0] === "id" || /^-+$/.test(cells[0])) continue;
  const [id, verdict] = cells;
  if (!["match", "no-match", "undecidable"].includes(verdict)) { out.error = `bad verdict for ${id}: ${verdict}`; continue; }
  verdicts.set(id, verdict);
}
if (!out.error && verdicts.size === 0) out.error = "empty rubric-verdict table";

// apply requirements
const reqs = [];
const apply = (r) => {
  const [k, v, ...rest] = r.split(":");
  if (k === "human_review") { if (v !== "none" && !out.human_review.includes(v)) out.human_review.push(v); }
  else if (k === "design" && v === "required") out.design_required = true;
  else if (k === "human_check") out.human_checks.push({ phase: v, what: rest.join(":") });
  else if (k === "mergeable_by") reqs.push(v);
  else out.error ??= `unknown requirement ${r}`;
};
for (const [id, v] of verdicts) {
  if (!rules.has(id)) { out.unknown.push(id); continue; }
  if (v === "match") { out.matched.push(id); rules.get(id).forEach(apply); }
  else if (v === "undecidable") { out.undecidable.push(id); defaults.undecidable.forEach(apply); }
}
for (const id of rules.keys()) if (!verdicts.has(id)) { out.undecidable.push(id); defaults.undecidable.forEach(apply); }
if (out.matched.length === 0 && out.undecidable.length === 0) defaults["no-match"].forEach(apply);
else if (reqs.length === 0) defaults["no-match"].filter(r => r.startsWith("mergeable_by:")).forEach(apply); // matched rules that do not decide who merges leave it to the default
if (out.unknown.length) out.error ??= `unknown rule id(s): ${out.unknown.join(",")}`;
if (out.error) (defaults.undecidable && defaults.undecidable.length ? defaults.undecidable : ["human_review:proposal", "mergeable_by:human"]).forEach(apply); // an unreadable verdict is treated like an undecidable one
if (out.error || out.undecidable.length) out.mergeable_by = "human";
else out.mergeable_by = reqs.includes("human") ? "human" : reqs.includes("handler") ? "handler" : "human";
process.stdout.write(JSON.stringify(out) + "\n");
