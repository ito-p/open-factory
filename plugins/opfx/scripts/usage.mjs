#!/usr/bin/env node
// usage.mjs — sum token usage from Claude Code transcript JSONL files and estimate cost.
// usage.sh (<jsonl>|--agent <id>|--session) [--since ISO] [--until ISO] [--role R] [--change C] [--phase P] [--line]
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

const args = process.argv.slice(2);
const opt = { files: [], since: null, until: null, role: "", change: "", phase: "", line: false };
function usage(msg) {
  process.stderr.write(`usage: usage.sh (<jsonl>|--agent <id>|--session) [--since ISO] [--until ISO] [--role R] [--change C] [--phase P] [--line]\n${msg ?? ""}\n`);
  process.exit(2);
}
function walk(dir, depth, out) {
  if (depth < 0 || !existsSync(dir)) return out;
  for (const e of readdirSync(dir)) { const p = join(dir, e); try { if (statSync(p).isDirectory()) walk(p, depth - 1, out); else out.push(p); } catch {} }
  return out;
}
function findAgent(id) {
  const root = join(homedir(), ".claude", "projects");
  return walk(root, 4, []).filter(p => p.endsWith(`/subagents/agent-${id}.jsonl`));
}
function findSession() {
  const enc = (process.env.OPFX_ROOT || process.cwd()).replace(/[^a-zA-Z0-9]/g, "-");
  const dir = join(homedir(), ".claude", "projects", enc);
  if (!existsSync(dir)) usage(`no session dir ${dir}`);
  const files = readdirSync(dir).filter(f => f.endsWith(".jsonl")).map(f => join(dir, f)).sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs);
  if (!files.length) usage("no session transcript");
  return files[0];
}
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--since") opt.since = args[++i];
  else if (a === "--until") opt.until = args[++i];
  else if (a === "--role") opt.role = args[++i];
  else if (a === "--change") opt.change = args[++i];
  else if (a === "--phase") opt.phase = args[++i];
  else if (a === "--line") opt.line = true;
  else if (a === "--agent") opt.files.push(...findAgent(args[++i]));
  else if (a === "--session") opt.files.push(findSession());
  else opt.files.push(a);
}
if (!opt.files.length) usage();
for (const f of opt.files) if (!existsSync(f)) usage(`no such file ${f}`);

const pricingPath = process.env.OPFX_PRICING || join(new URL(".", import.meta.url).pathname, "..", "pricing.json");
const pricing = existsSync(pricingPath) ? JSON.parse(readFileSync(pricingPath, "utf8")) : { per_mtok: {} };

const seen = new Set(); const byModel = new Map(); const warnings = [];
let first = null, last = null, tools = 0;
for (const f of opt.files) for (const line of readFileSync(f, "utf8").split("\n")) {
  if (!line.trim()) continue;
  let r; try { r = JSON.parse(line); } catch { continue; }
  const ts = r.timestamp || "";
  if (opt.since && ts < opt.since) continue;
  if (opt.until && ts > opt.until) continue;
  if (r.type !== "assistant" || !r.message?.usage) continue;
  // tool_use blocks are spread over the records of one API response: count them all, but count usage once per requestId
  if (Array.isArray(r.message.content)) tools += r.message.content.filter(b => b.type === "tool_use").length;
  const key = r.requestId || r.uuid; if (seen.has(key)) continue; seen.add(key);
  first ??= ts; last = ts;
  const u = r.message.usage, m = r.message.model || "unknown";
  const cur = byModel.get(m) || { model: m, in: 0, out: 0, cache_w: 0, cache_w_1h: 0, cache_r: 0, n: 0 };
  cur.in += u.input_tokens || 0; cur.out += u.output_tokens || 0; cur.cache_w += u.cache_creation_input_tokens || 0;
  cur.cache_w_1h += u.cache_creation?.ephemeral_1h_input_tokens || 0; cur.cache_r += u.cache_read_input_tokens || 0; cur.n++;
  byModel.set(m, cur);
}
const models = [...byModel.values()].map(x => {
  const p = pricing.per_mtok?.[x.model]; let est = null;
  if (p) { const w5 = x.cache_w - x.cache_w_1h; est = (x.in * p.input + x.out * p.output + w5 * p.cache_write_5m + x.cache_w_1h * p.cache_write_1h + x.cache_r * p.cache_read) / 1e6; }
  else warnings.push(`no price for ${x.model}`);
  return { ...x, est_usd: est === null ? null : Number(est.toFixed(6)) };
});
const total = models.reduce((t, x) => ({
  in: t.in + x.in, out: t.out + x.out, cache_w: t.cache_w + x.cache_w, cache_r: t.cache_r + x.cache_r,
  est_usd: x.est_usd === null || t.est_usd === null ? null : Number((t.est_usd + x.est_usd).toFixed(6)),
}), { in: 0, out: 0, cache_w: 0, cache_r: 0, est_usd: 0 });
if (opt.line) {
  const fmt = n => n.toLocaleString("en-US");
  const dur = first && last ? Math.max(0, (Date.parse(last) - Date.parse(first)) / 1000) : 0;
  const mmss = `${String(Math.floor(dur / 60)).padStart(2, "0")}:${String(Math.floor(dur % 60)).padStart(2, "0")}`;
  const est = total.est_usd === null ? "n/a" : `$${total.est_usd.toFixed(4)}`;
  const modelStr = models.map(x => x.model).join("+") || "unknown";
  process.stdout.write(`${opt.role || "agent"} ${opt.change || "-"} | phase=${opt.phase || "all"} | model=${modelStr} | in=${fmt(total.in)} out=${fmt(total.out)} cache_w=${fmt(total.cache_w)} cache_r=${fmt(total.cache_r)} | est=${est} | ${mmss} | tools=${tools}\n`);
} else {
  process.stdout.write(JSON.stringify({ files: opt.files, models, total, warnings, asof: pricing.asof ?? null }) + "\n");
}
