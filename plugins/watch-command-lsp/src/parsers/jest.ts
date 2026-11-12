import { Diagnostic, DiagnosticSeverity, OutputParser } from "../types.js";

/**
 * Parser for Jest test output (--watch or --watchAll).
 *
 * Jest output includes:
 *   FAIL src/foo.test.ts
 *     ● Test suite name › test case name
 *       Expected: 1
 *       Received: 2
 *
 *       at Object.<anonymous> (src/foo.test.ts:10:5)
 *
 *   Test Suites: 1 failed, 2 passed, 3 total
 *   Tests:       1 failed, 5 passed, 6 total
 */
const FAIL_SUITE = /^FAIL\s+(.+)$/;
const PASS_SUITE = /^PASS\s+(.+)$/;
const TEST_NAME = /^\s+[●✕✖]\s+(.+)$/;
const STACK_LOCATION = /at\s+.+?\((?<file>[^:)]+):(?<line>\d+):(?<col>\d+)\)/;
const SUMMARY_LINE = /^(Test Suites|Tests|Snapshots|Time):/;
const JEST_WATCH_USAGE = /^Watch Usage/;

enum ParseState {
  Idle,
  InFailingSuite,
  InTestCase,
}

export class JestParser implements OutputParser {
  name = "jest";
  private buffer = "";
  private state = ParseState.Idle;
  private currentSuiteFile = "";
  private currentTestName = "";
  private currentMessage: string[] = [];

  parse(output: string, source: string): Diagnostic[] {
    this.buffer += output;
    const lines = this.buffer.split("\n");
    this.buffer = lines.pop() ?? "";

    const diagnostics: Diagnostic[] = [];
    for (const line of lines) {
      const trimmed = line.trimEnd();

      // Skip watch usage prompt and summary lines
      if (JEST_WATCH_USAGE.test(trimmed) || SUMMARY_LINE.test(trimmed)) {
        this.emitCurrent(diagnostics, source);
        this.state = ParseState.Idle;
        continue;
      }

      // New passing suite resets state
      if (PASS_SUITE.test(trimmed)) {
        this.emitCurrent(diagnostics, source);
        this.state = ParseState.Idle;
        continue;
      }

      // New failing suite
      const failMatch = trimmed.match(FAIL_SUITE);
      if (failMatch) {
        this.emitCurrent(diagnostics, source);
        this.currentSuiteFile = failMatch[1].trim();
        this.state = ParseState.InFailingSuite;
        continue;
      }

      if (this.state === ParseState.Idle) continue;

      // Test case name
      const testMatch = trimmed.match(TEST_NAME);
      if (testMatch) {
        this.emitCurrent(diagnostics, source);
        this.currentTestName = testMatch[1];
        this.currentMessage = [];
        this.state = ParseState.InTestCase;
        continue;
      }

      // Stack trace with file location
      if (this.state === ParseState.InTestCase) {
        const stackMatch = trimmed.match(STACK_LOCATION);
        if (stackMatch?.groups) {
          this.currentMessage.push(trimmed.trim());
          diagnostics.push({
            file: stackMatch.groups.file,
            line: parseInt(stackMatch.groups.line, 10),
            column: parseInt(stackMatch.groups.col, 10),
            severity: DiagnosticSeverity.Error,
            message: `${this.currentTestName}\n${this.currentMessage.join("\n")}`,
            source,
          });
          this.currentMessage = [];
          this.currentTestName = "";
          this.state = ParseState.InFailingSuite;
          continue;
        }

        // Accumulate message lines
        if (trimmed.trim()) {
          this.currentMessage.push(trimmed.trim());
        }
      }
    }
    return diagnostics;
  }

  private emitCurrent(diagnostics: Diagnostic[], source: string): void {
    if (this.state === ParseState.InTestCase && this.currentTestName && this.currentSuiteFile) {
      // No stack location found — use suite file, line 1
      diagnostics.push({
        file: this.currentSuiteFile,
        line: 1,
        column: 0,
        severity: DiagnosticSeverity.Error,
        message: `${this.currentTestName}\n${this.currentMessage.join("\n")}`,
        source,
      });
      this.currentTestName = "";
      this.currentMessage = [];
    }
  }

  flush(source: string): Diagnostic[] {
    const remaining = this.buffer.trim() ? this.parse("\n", source) : [];
    const final: Diagnostic[] = [...remaining];
    this.emitCurrent(final, source);
    this.buffer = "";
    this.state = ParseState.Idle;
    this.currentSuiteFile = "";
    this.currentTestName = "";
    this.currentMessage = [];
    return final;
  }

  reset(): void {
    this.buffer = "";
    this.state = ParseState.Idle;
    this.currentSuiteFile = "";
    this.currentTestName = "";
    this.currentMessage = [];
  }
}
