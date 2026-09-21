import { Diagnostic, DiagnosticSeverity, OutputParser } from "../types.js";

/**
 * Generic parser that matches common compiler/linter output formats:
 *   file:line:col: severity: message
 *   file(line,col): severity message
 *   file:line: message
 */
const PATTERNS = [
  // GCC/Clang/TSC/ESLint style: file:line:col: error: message
  /^(?<file>[^\s:()]+):(?<line>\d+):(?<col>\d+):\s*(?<sev>error|warning|info|hint|note):\s*(?<msg>.+)$/,
  // file:line:col: message (no severity keyword)
  /^(?<file>[^\s:()]+):(?<line>\d+):(?<col>\d+):\s*(?<msg>.+)$/,
  // Visual Studio style: file(line,col): error CODE: message
  /^(?<file>[^\s()]+)\((?<line>\d+),(?<col>\d+)\):\s*(?<sev>error|warning)\s+(?<code>\w+):\s*(?<msg>.+)$/,
  // Simple: file:line: message
  /^(?<file>[^\s:()]+):(?<line>\d+):\s*(?<msg>.+)$/,
];

function parseSeverity(sev?: string): DiagnosticSeverity {
  switch (sev?.toLowerCase()) {
    case "error":
      return DiagnosticSeverity.Error;
    case "warning":
    case "warn":
      return DiagnosticSeverity.Warning;
    case "info":
    case "information":
      return DiagnosticSeverity.Information;
    case "hint":
    case "note":
      return DiagnosticSeverity.Hint;
    default:
      return DiagnosticSeverity.Error;
  }
}

export class GenericParser implements OutputParser {
  name = "generic";
  private buffer = "";

  parse(output: string, source: string): Diagnostic[] {
    this.buffer += output;
    const lines = this.buffer.split("\n");
    // Keep last incomplete line in buffer
    this.buffer = lines.pop() ?? "";

    const diagnostics: Diagnostic[] = [];
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      for (const pattern of PATTERNS) {
        const match = trimmed.match(pattern);
        if (match?.groups) {
          diagnostics.push({
            file: match.groups.file,
            line: parseInt(match.groups.line, 10),
            column: parseInt(match.groups.col ?? "0", 10),
            severity: parseSeverity(match.groups.sev),
            message: match.groups.msg.trim(),
            source,
            code: match.groups.code,
          });
          break;
        }
      }
    }
    return diagnostics;
  }

  flush(source: string): Diagnostic[] {
    if (this.buffer.trim()) {
      const result = this.parse("\n", source);
      this.buffer = "";
      return result;
    }
    return [];
  }

  reset(): void {
    this.buffer = "";
  }
}
