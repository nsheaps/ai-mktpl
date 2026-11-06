/** Severity levels for diagnostics, modeled after LSP DiagnosticSeverity */
export enum DiagnosticSeverity {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4,
}

/** A single diagnostic (error/warning) from a watch command */
export interface Diagnostic {
  /** Absolute or relative file path */
  file: string;
  /** 1-based line number */
  line: number;
  /** 1-based column number (0 if unknown) */
  column: number;
  severity: DiagnosticSeverity;
  /** The error/warning message */
  message: string;
  /** Source identifier (e.g. "eslint", "tsc", "jest") */
  source: string;
  /** Optional rule or error code */
  code?: string;
}

/** Known parser types */
export type ParserType = "generic" | "jest" | "eslint" | "tsc" | "regex";

/** Configuration for a single watcher */
export interface WatcherConfig {
  /** Unique identifier for this watcher */
  id: string;
  /** The shell command to run (e.g. "npx jest --watch") */
  command: string;
  /** Working directory for the command */
  cwd?: string;
  /** Which parser to use for output */
  parser: ParserType;
  /** Custom regex patterns (only used when parser is "regex") */
  regexPatterns?: RegexPatternConfig[];
  /** Environment variables to set */
  env?: Record<string, string>;
  /** Shell to use (default: /bin/sh) */
  shell?: string;
}

/** Custom regex pattern configuration for the "regex" parser */
export interface RegexPatternConfig {
  /** Regex pattern with named groups: file, line, column, message, severity, code */
  pattern: string;
  /** Flags for the regex (default: "gm") */
  flags?: string;
}

/** Runtime state of a watcher */
export interface WatcherState {
  config: WatcherConfig;
  /** Process ID of the running command */
  pid: number | null;
  /** Whether the watcher is currently running */
  running: boolean;
  /** Current accumulated diagnostics */
  diagnostics: Diagnostic[];
  /** Raw output buffer (last N lines) */
  outputBuffer: string[];
  /** When the watcher was started */
  startedAt: Date | null;
  /** When diagnostics were last updated */
  lastUpdated: Date | null;
  /** Exit code if the process has exited */
  exitCode: number | null;
}

/** Interface that all output parsers must implement */
export interface OutputParser {
  /** Human-readable name of the parser */
  name: string;
  /**
   * Parse a chunk of output and return diagnostics.
   * The parser may buffer partial lines internally.
   */
  parse(output: string, source: string): Diagnostic[];
  /**
   * Signal that the current output cycle is complete
   * (e.g. jest finished a test run). Returns any remaining diagnostics.
   */
  flush(source: string): Diagnostic[];
  /** Reset internal state */
  reset(): void;
}
