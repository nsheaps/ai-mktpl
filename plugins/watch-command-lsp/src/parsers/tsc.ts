import { Diagnostic, DiagnosticSeverity, OutputParser } from "../types.js";

/**
 * Parser for TypeScript compiler (tsc --watch) output.
 *
 * Matches lines like:
 *   src/index.ts(5,10): error TS2322: Type 'string' is not assignable to type 'number'.
 *   src/index.ts:5:10 - error TS2322: Type 'string' is not assignable to type 'number'.
 */
const TSC_PATTERN_PARENS =
  /^(?<file>.+?)\((?<line>\d+),(?<col>\d+)\):\s*(?<sev>error|warning)\s+(?<code>TS\d+):\s*(?<msg>.+)$/;
const TSC_PATTERN_COLON =
  /^(?<file>.+?):(?<line>\d+):(?<col>\d+)\s*-\s*(?<sev>error|warning)\s+(?<code>TS\d+):\s*(?<msg>.+)$/;
const TSC_SUMMARY = /Found\s+(?<count>\d+)\s+error/;
const TSC_WATCHING = /Watching for file changes/;

export class TscParser implements OutputParser {
  name = "tsc";
  private buffer = "";
  private currentDiagnostics: Diagnostic[] = [];

  parse(output: string, source: string): Diagnostic[] {
    this.buffer += output;
    const lines = this.buffer.split("\n");
    this.buffer = lines.pop() ?? "";

    const diagnostics: Diagnostic[] = [];
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      // Check for new compilation cycle
      if (TSC_WATCHING.test(trimmed) || TSC_SUMMARY.test(trimmed)) {
        // A new cycle — replace accumulated diagnostics
        if (diagnostics.length > 0 || this.currentDiagnostics.length > 0) {
          this.currentDiagnostics = [...diagnostics];
        }
        continue;
      }

      for (const pattern of [TSC_PATTERN_PARENS, TSC_PATTERN_COLON]) {
        const match = trimmed.match(pattern);
        if (match?.groups) {
          diagnostics.push({
            file: match.groups.file,
            line: parseInt(match.groups.line, 10),
            column: parseInt(match.groups.col, 10),
            severity:
              match.groups.sev === "error" ? DiagnosticSeverity.Error : DiagnosticSeverity.Warning,
            message: match.groups.msg.trim(),
            source,
            code: match.groups.code,
          });
          break;
        }
      }
    }

    if (diagnostics.length > 0) {
      this.currentDiagnostics = diagnostics;
    }
    return diagnostics;
  }

  flush(source: string): Diagnostic[] {
    const remaining = this.buffer.trim() ? this.parse("\n", source) : [];
    this.buffer = "";
    return remaining;
  }

  reset(): void {
    this.buffer = "";
    this.currentDiagnostics = [];
  }
}
