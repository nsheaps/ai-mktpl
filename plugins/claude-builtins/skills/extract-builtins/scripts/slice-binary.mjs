// Slice a byte range out of the Claude Code binary and normalize it to a
// text file that a beautifier can parse. Non-printable bytes become newlines
// so js-beautify has clean token boundaries.
//
// Usage:
//   node slice-binary.mjs <binary> <out.js> <startOffset> <endOffset>
//
// The offsets are REAL byte offsets into the binary. Get them from the leading
// column of `strings -t d` (see SKILL.md), or from `grep -aob` run on the binary
// itself. Never take an offset out of an intermediate stream (e.g.
// `strings <bin> | grep -b …`) — that indexes the dump, not the file.
import { openSync, readSync, closeSync, writeFileSync } from "node:fs";

const [, , binPath, outName, sStr, eStr] = process.argv;
if (!binPath || !outName || !sStr || !eStr) {
  console.error("usage: node slice-binary.mjs <binary> <out.js> <startOffset> <endOffset>");
  process.exit(2);
}

const start = Number(sStr);
const end = Number(eStr);
if (!Number.isInteger(start) || !Number.isInteger(end) || start < 0 || end <= start) {
  console.error(`bad offsets [${sStr}, ${eStr}) — expected integers with 0 <= start < end`);
  console.error(
    "use the leading decimal column from `strings -t d` (or `grep -aob` on the binary), not an offset from a piped stream",
  );
  process.exit(2);
}

// Range-read just the requested window — the binary is ~245MB, so never slurp it
// all. readSync may return fewer bytes than asked (EOF / short read); trim to what
// we actually got.
const want = end - start;
// The binary is ~245MB; a window larger than that is a mistyped offset, not a
// real request. Catch it here so it fails with a message rather than a raw
// `Array buffer allocation failed` out of Buffer.allocUnsafe.
if (want > 512 * 1024 * 1024) {
  console.error(`window of ${want} bytes is implausibly large — check the end offset`);
  process.exit(2);
}
const buf = Buffer.allocUnsafe(want);
const fd = openSync(binPath, "r");
let got;
try {
  got = readSync(fd, buf, 0, want, start);
} finally {
  closeSync(fd);
}
if (got === 0) {
  console.error(`read 0 bytes at offset ${start} — is the offset past end-of-file?`);
  process.exit(1);
}
const slice = buf.subarray(0, got);

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
const actualEnd = start + got;
const trimmedNote = actualEnd < end ? ` (short read: wanted end ${end})` : "";
console.log(
  `wrote ${outName} (${out.length} bytes) from ${binPath} [${start}, ${actualEnd})${trimmedNote}`,
);
