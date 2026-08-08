// Slice a byte range out of the Claude Code binary and normalize it to a
// text file that a beautifier can parse. Non-printable bytes become newlines
// so js-beautify has clean token boundaries.
//
// Usage:
//   node slice-binary.mjs <binary> <out.js> <startOffset> <endOffset>
//
// The offsets are REAL byte offsets into the binary. Get them from the leading
// column of `strings -t d` (see SKILL.md) — NOT from `grep -aob`, whose offsets
// are into grep's own filtered stream, not the file.
import { readFileSync, writeFileSync } from "node:fs";

const [, , binPath, outName, sStr, eStr] = process.argv;
if (!binPath || !outName || !sStr || !eStr) {
  console.error("usage: node slice-binary.mjs <binary> <out.js> <startOffset> <endOffset>");
  process.exit(2);
}

const buf = readFileSync(binPath);
const start = Number(sStr);
const end = Number(eStr);
if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || end <= start) {
  console.error(`bad offsets [${sStr}, ${eStr}) — expected integers with 0 <= start < end`);
  console.error("use the leading decimal column from `strings -t d`, not `grep -aob`");
  process.exit(2);
}
const slice = buf.subarray(start, end);

let out = "";
for (const b of slice) {
  // keep tab / LF / CR / printable ASCII; everything else → newline
  if (b === 9 || b === 10 || b === 13 || (b >= 32 && b < 127)) {
    out += String.fromCharCode(b);
  } else {
    out += "\n";
  }
}

writeFileSync(outName, out);
console.log(`wrote ${outName} (${out.length} bytes) from ${binPath} [${start}, ${end})`);
