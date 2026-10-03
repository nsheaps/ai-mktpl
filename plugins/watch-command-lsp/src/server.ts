#!/usr/bin/env node
import {
  createConnection,
  TextDocuments,
  ProposedFeatures,
  InitializeParams,
  InitializeResult,
  TextDocumentSyncKind,
  Diagnostic as LspDiagnostic,
  DiagnosticSeverity as LspDiagnosticSeverity,
} from "vscode-languageserver/node.js";
import { TextDocument } from "vscode-languageserver-textdocument";
import { resolve } from "path";
import { WatcherManager } from "./watcher.js";
import { Diagnostic, DiagnosticSeverity, WatcherConfig, ParserType } from "./types.js";

/** Shape of initializationOptions passed from .lsp.json */
interface WatchCommandInitOptions {
  watchers?: Array<{
    id: string;
    command: string;
    parser: ParserType;
    cwd?: string;
    env?: Record<string, string>;
    shell?: string;
    regexPatterns?: Array<{ pattern: string; flags?: string }>;
  }>;
}

const connection = createConnection(ProposedFeatures.all);
const documents = new TextDocuments(TextDocument);
const manager = new WatcherManager();

let workspaceRoot: string | null = null;

// Convert our diagnostic severity to LSP severity
function toLspSeverity(severity: DiagnosticSeverity): LspDiagnosticSeverity {
  switch (severity) {
    case DiagnosticSeverity.Error:
      return LspDiagnosticSeverity.Error;
    case DiagnosticSeverity.Warning:
      return LspDiagnosticSeverity.Warning;
    case DiagnosticSeverity.Information:
      return LspDiagnosticSeverity.Information;
    case DiagnosticSeverity.Hint:
      return LspDiagnosticSeverity.Hint;
  }
}

// Convert our diagnostics to LSP diagnostics and publish them
function publishDiagnostics(
  _watcherId: string,
  diagnosticsByFile: Map<string, Diagnostic[]>,
): void {
  // Collect all files we know about from all watchers so we can clear stale ones
  const allByFile = manager.getAllDiagnosticsByFile();

  // Publish diagnostics for every file that has (or had) diagnostics
  const allFiles = new Set([...allByFile.keys(), ...diagnosticsByFile.keys()]);
  for (const file of allFiles) {
    const filePath = resolve(workspaceRoot ?? ".", file);
    const uri = `file://${filePath}`;
    const diags = allByFile.get(file) ?? [];

    const lspDiags: LspDiagnostic[] = diags.map((d) => ({
      severity: toLspSeverity(d.severity),
      range: {
        start: {
          line: Math.max(0, d.line - 1), // LSP is 0-based
          character: Math.max(0, d.column - 1),
        },
        end: {
          line: Math.max(0, d.line - 1),
          character: Math.max(0, d.column),
        },
      },
      message: d.message,
      source: d.source,
      ...(d.code ? { code: d.code } : {}),
    }));

    connection.sendDiagnostics({ uri, diagnostics: lspDiags });
  }
}

connection.onInitialize((params: InitializeParams): InitializeResult => {
  workspaceRoot = params.rootPath ?? (params.rootUri ? new URL(params.rootUri).pathname : null);

  // Register the diagnostic change callback
  manager.setDiagnosticChangeCallback(publishDiagnostics);

  // Start watchers from initializationOptions
  const options = params.initializationOptions as WatchCommandInitOptions | undefined;
  if (options?.watchers) {
    for (const w of options.watchers) {
      const config: WatcherConfig = {
        id: w.id,
        command: w.command,
        parser: w.parser,
        cwd: w.cwd ?? workspaceRoot ?? undefined,
        env: w.env,
        shell: w.shell,
        regexPatterns: w.regexPatterns,
      };
      try {
        manager.start(config);
        connection.console.log(`[watch-command-lsp] Started watcher "${w.id}": ${w.command}`);
      } catch (err) {
        connection.console.error(`[watch-command-lsp] Failed to start watcher "${w.id}": ${err}`);
      }
    }
  }

  return {
    capabilities: {
      textDocumentSync: TextDocumentSyncKind.Incremental,
      // We're a diagnostics-only server — no completion, hover, etc.
    },
  };
});

connection.onInitialized(() => {
  connection.console.log("[watch-command-lsp] Server initialized");
});

connection.onShutdown(() => {
  connection.console.log("[watch-command-lsp] Shutting down, stopping all watchers");
  manager.stopAll();
});

// Graceful shutdown on signals
process.on("SIGINT", () => {
  manager.stopAll();
  process.exit(0);
});
process.on("SIGTERM", () => {
  manager.stopAll();
  process.exit(0);
});

documents.listen(connection);
connection.listen();
