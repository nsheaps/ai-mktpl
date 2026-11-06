import { Diagnostic, DiagnosticSeverity, OutputParser } from "../types.js";

/**
 * Parser for ESLint output (default formatter).
 *
 * ESLint default formatter output looks like:
 *
 *   /path/to/file.js
 *     2:10  error    Unexpected var    no-var
 *     5:1   warning  Missing semicolon semi
 *
 *   ✖ 2 problems (1 error, 1 warning)
 */
const FILE_HEADER = /^([/.][\S]+)$/;
const DIAGNOSTIC_LINE =
  /^\s+(?<line>\d+):(?<col>\d+)\s+(?<sev>error|warning)\s+(?<msg>.+?)\s{2,}(?<code>\S+)\s*$/;
const SUMMARY_LINE = /^[✖✗×]\s+\d+\s+problem/;

export class EslintParser implements OutputParser {
  name = "eslint";
  private buffer = "";
  private currentFile = "";

  parse(output: string, source: string): Diagnostic[] {
    this.buffer += output;
    const lines = this.buffer.split("\n");
    this.buffer = lines.pop() ?? "";

    const diagnostics: Diagnostic[] = [];
    for (const line of lines) {
      // Skip empty lines and summary
      if (!line.trim() || SUMMARY_LINE.test(line.trim())) continue;

      // Check for file header
      const fileMatch = line.trim().match(FILE_HEADER);
      if (fileMatch) {
        this.currentFile = fileMatch[1];
        continue;
      }

      // Check for diagnostic line
      const diagMatch = line.match(DIAGNOSTIC_LINE);
      if (diagMatch?.groups && this.currentFile) {
        diagnostics.push({
          file: this.currentFile,
          line: parseInt(diagMatch.groups.line, 10),
          column: parseInt(diagMatch.groups.col, 10),
          severity:
            diagMatch.groups.sev === "error"
              ? DiagnosticSeverity.Error
              : DiagnosticSeverity.Warning,
          message: diagMatch.groups.msg.trim(),
          source,
          code: diagMatch.groups.code,
        });
      }
    }
    return diagnostics;
  }

  flush(source: string): Diagnostic[] {
    const remaining = this.buffer.trim() ? this.parse("\n", source) : [];
    this.buffer = "";
    this.currentFile = "";
    return remaining;
  }

  reset(): void {
    this.buffer = "";
    this.currentFile = "";
  }
}
