import { Diagnostic, DiagnosticSeverity, OutputParser, RegexPatternConfig } from "../types.js";

/**
 * User-configurable regex parser.
 * Uses named capture groups: file, line, column, message, severity, code
 */
export class RegexParser implements OutputParser {
  name = "regex";
  private buffer = "";
  private regexes: RegExp[];

  constructor(patterns: RegexPatternConfig[]) {
    this.regexes = patterns.map((p) => new RegExp(p.pattern, p.flags ?? "gm"));
  }

  parse(output: string, source: string): Diagnostic[] {
    this.buffer += output;
    const lines = this.buffer.split("\n");
    this.buffer = lines.pop() ?? "";

    const diagnostics: Diagnostic[] = [];
    for (const line of lines) {
      if (!line.trim()) continue;
      for (const regex of this.regexes) {
        regex.lastIndex = 0;
        const match = regex.exec(line);
        if (match?.groups) {
          diagnostics.push({
            file: match.groups.file ?? "<unknown>",
            line: parseInt(match.groups.line ?? "1", 10),
            column: parseInt(match.groups.column ?? "0", 10),
            severity: this.parseSeverity(match.groups.severity),
            message: match.groups.message ?? line.trim(),
            source,
            code: match.groups.code,
          });
          break;
        }
      }
    }
    return diagnostics;
  }

  private parseSeverity(sev?: string): DiagnosticSeverity {
    switch (sev?.toLowerCase()) {
      case "error":
        return DiagnosticSeverity.Error;
      case "warning":
      case "warn":
        return DiagnosticSeverity.Warning;
      default:
        return DiagnosticSeverity.Error;
    }
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
