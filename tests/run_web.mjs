import fs from "node:fs";
import path from "node:path";

const html = fs.readFileSync(path.join(import.meta.dirname, "..", "web", "PCPath_v1.3.0.html"), "utf8");

// Extract a named function's full source by brace-matching.
function grab(name) {
  const i = html.indexOf("function " + name);
  if (i < 0) throw new Error("not found: " + name);
  let depth = 0;
  for (let k = html.indexOf("{", i); k < html.length; k++) {
    if (html[k] === "{") depth++;
    else if (html[k] === "}" && --depth === 0) return html.slice(i, k + 1);
  }
  throw new Error("unbalanced: " + name);
}

// Test context: minimal globals the functions reference.
const ctx = { mappings: [{ vol: "EDIT", letter: "E" }], stripSuffixes: [] };
function load(...names) {
  const src = names.map(grab).join("\n");
  // eslint-disable-next-line no-new-func
  return new Function(...Object.keys(ctx), src + "\nreturn {normalizeMacLike,detectType,macToPC,pcToMac" +
    (src.includes("function stripWrappingQuotes") ? ",stripWrappingQuotes" : "") +
    (src.includes("function stripSegmentSuffixes") ? ",stripSegmentSuffixes" : "") +
    "};")(...Object.values(ctx));
}

let failures = 0;
function eq(actual, expected, label) {
  if (actual === expected) { console.log(`  ok  ${label}`); }
  else { failures++; console.log(`FAIL  ${label}\n        expected: ${expected}\n        actual:   ${actual}`); }
}

// --- Preservation witness (current behavior) ---
{
  const fns = load("normalizeMacLike", "detectType", "macToPC", "pcToMac");
  const bs = String.fromCharCode(92);
  const input = "/Volumes/EDIT/EastofEden_ESED/Media/GFX/TO GFX/20260610/tim_edt_trl_Beauty_v5_wip04_wm.mp4".replace(/[/]/g, bs);
  const line = fns.normalizeMacLike(input.trim());
  eq(fns.macToPC(line), "E:" + bs + "EastofEden_ESED" + bs + "Media" + bs + "GFX" + bs + "TO GFX" + bs + "20260610" + bs + "tim_edt_trl_Beauty_v5_wip04_wm.mp4", "web: space + filename preserved");
}

export { html, grab, load, eq };
globalThis.__pcpathFailures = (globalThis.__pcpathFailures ?? 0) + failures;
process.on("exit", () => process.exit(globalThis.__pcpathFailures ? 1 : 0));
