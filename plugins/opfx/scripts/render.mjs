#!/usr/bin/env node
// render.mjs <template> <out> KEY=VALUE... — replaces every {{KEY}}; a VALUE starting with @ is read from that file.
import { readFileSync, writeFileSync } from "node:fs";
const [tpl, out, ...kv] = process.argv.slice(2);
if (!tpl || !out) { process.stderr.write("usage: render.mjs <template> <out> KEY=VALUE...\n"); process.exit(2); }
let s = readFileSync(tpl, "utf8");
for (const p of kv) {
  const i = p.indexOf("="); const k = p.slice(0, i); let v = p.slice(i + 1);
  if (v.startsWith("@")) v = readFileSync(v.slice(1), "utf8").replace(/\n$/, "");
  s = s.split(`{{${k}}}`).join(v);
}
writeFileSync(out, s);
