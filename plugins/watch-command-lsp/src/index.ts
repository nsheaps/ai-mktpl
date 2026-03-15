#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  type Tool,
} from "@modelcontextprotocol/sdk/types.js";
import { WatcherManager } from "./watcher.js";
import { DiagnosticSeverity, type ParserType } from "./types.js";

const manager = new WatcherManager();

const tools: Tool[] = [
  {
    name: "start_watcher",
    description:
      "Start a watch command that continuously monitors for changes. " +
      "Diagnostics (errors, warnings) are parsed from the command output and can be queried with get_diagnostics. " +
      "Use this for test runners (jest --watch), linters (eslint --watch), or compilers (tsc --watch).",
    inputSchema: {
      type: "object" as const,
      properties: {
        id: {
          type: "string",
          description: "Unique identifier for this watcher (e.g. 'jest', 'eslint', 'tsc')",
        },
        command: {
          type: "string",
          description: "Shell command to run (e.g. 'npx jest --watchAll --no-coverage')",
        },
        parser: {
          type: "string",
          enum: ["generic", "jest", "eslint", "tsc", "regex"],
          description:
            "Output parser to use. 'generic' matches file:line:col patterns. " +
            "Specialized parsers (jest, eslint, tsc) understand tool-specific output formats.",
        },
        cwd: {
          type: "string",
          description: "Working directory for the command (default: server cwd)",
        },
        env: {
          type: "object",
          description: "Additional environment variables to set",
          additionalProperties: { type: "string" },
        },
        regexPatterns: {
          type: "array",
          description:
            "Custom regex patterns (only for parser='regex'). " +
            "Each pattern should have named groups: file, line, column, message, severity, code",
          items: {
            type: "object",
            properties: {
              pattern: { type: "string" },
              flags: { type: "string", default: "gm" },
            },
            required: ["pattern"],
          },
        },
      },
      required: ["id", "command", "parser"],
    },
  },
  {
    name: "stop_watcher",
    description: "Stop a running watch command and clean up its process.",
    inputSchema: {
      type: "object" as const,
      properties: {
        id: {
          type: "string",
          description: "ID of the watcher to stop",
        },
      },
      required: ["id"],
    },
  },
  {
    name: "list_watchers",
    description:
      "List all active watchers with their status (running, pid, diagnostic count, last updated).",
    inputSchema: {
      type: "object" as const,
      properties: {},
    },
  },
  {
    name: "get_diagnostics",
    description:
      "Get current diagnostics (errors and warnings) from watch commands. " +
      "Returns structured data with file, line, column, severity, and message. " +
      "Optionally filter by watcher ID, severity, or file path.",
    inputSchema: {
      type: "object" as const,
      properties: {
        id: {
          type: "string",
          description:
            "Watcher ID to get diagnostics from. Omit to get diagnostics from all watchers.",
        },
        severity: {
          type: "string",
          enum: ["error", "warning", "info", "hint"],
          description: "Filter by severity level",
        },
        file: {
          type: "string",
          description: "Filter by file path (substring match)",
        },
      },
    },
  },
  {
    name: "get_output",
    description:
      "Get raw output lines from a watcher. Useful when the parser may not capture all relevant information.",
    inputSchema: {
      type: "object" as const,
      properties: {
        id: {
          type: "string",
          description: "Watcher ID to get output from",
        },
        lines: {
          type: "number",
          description: "Number of most recent lines to return (default: 50)",
        },
      },
      required: ["id"],
    },
  },
  {
    name: "clear_diagnostics",
    description:
      "Clear accumulated diagnostics for a watcher. Useful after fixing issues to see only new ones.",
    inputSchema: {
      type: "object" as const,
      properties: {
        id: {
          type: "string",
          description: "Watcher ID to clear diagnostics for",
        },
      },
      required: ["id"],
    },
  },
];

const server = new Server(
  {
    name: "watch-command-lsp",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case "start_watcher": {
        const config = {
          id: args!.id as string,
          command: args!.command as string,
          parser: args!.parser as ParserType,
          cwd: args?.cwd as string | undefined,
          env: args?.env as Record<string, string> | undefined,
          regexPatterns: args?.regexPatterns as { pattern: string; flags?: string }[] | undefined,
        };

        if (manager.has(config.id)) {
          return {
            content: [
              {
                type: "text" as const,
                text: `Watcher "${config.id}" is already running. Stop it first with stop_watcher.`,
              },
            ],
            isError: true,
          };
        }

        const state = manager.start(config);
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  status: "started",
                  id: config.id,
                  pid: state.pid,
                  command: config.command,
                  parser: config.parser,
                },
                null,
                2,
              ),
            },
          ],
        };
      }

      case "stop_watcher": {
        const id = args!.id as string;
        const state = manager.stop(id);
        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  status: "stopped",
                  id,
                  exitCode: state.exitCode,
                  diagnosticCount: state.diagnostics.length,
                },
                null,
                2,
              ),
            },
          ],
        };
      }

      case "list_watchers": {
        const watchers = manager.listWatchers();
        const summary = watchers.map((w) => ({
          id: w.config.id,
          command: w.config.command,
          parser: w.config.parser,
          running: w.running,
          pid: w.pid,
          diagnosticCount: w.diagnostics.length,
          errorCount: w.diagnostics.filter((d) => d.severity === DiagnosticSeverity.Error).length,
          warningCount: w.diagnostics.filter((d) => d.severity === DiagnosticSeverity.Warning)
            .length,
          startedAt: w.startedAt?.toISOString(),
          lastUpdated: w.lastUpdated?.toISOString(),
        }));
        return {
          content: [
            {
              type: "text" as const,
              text:
                watchers.length === 0 ? "No active watchers." : JSON.stringify(summary, null, 2),
            },
          ],
        };
      }

      case "get_diagnostics": {
        let diagnostics = manager.getDiagnostics(args?.id as string | undefined);

        // Filter by severity
        if (args?.severity) {
          const sevMap: Record<string, DiagnosticSeverity> = {
            error: DiagnosticSeverity.Error,
            warning: DiagnosticSeverity.Warning,
            info: DiagnosticSeverity.Information,
            hint: DiagnosticSeverity.Hint,
          };
          const targetSev = sevMap[args.severity as string];
          if (targetSev) {
            diagnostics = diagnostics.filter((d) => d.severity === targetSev);
          }
        }

        // Filter by file
        if (args?.file) {
          const fileFilter = args.file as string;
          diagnostics = diagnostics.filter((d) => d.file.includes(fileFilter));
        }

        const severityLabel = (s: DiagnosticSeverity) => {
          switch (s) {
            case DiagnosticSeverity.Error:
              return "error";
            case DiagnosticSeverity.Warning:
              return "warning";
            case DiagnosticSeverity.Information:
              return "info";
            case DiagnosticSeverity.Hint:
              return "hint";
          }
        };

        if (diagnostics.length === 0) {
          return {
            content: [
              {
                type: "text" as const,
                text: "No diagnostics found.",
              },
            ],
          };
        }

        const formatted = diagnostics.map((d) => ({
          file: d.file,
          line: d.line,
          column: d.column,
          severity: severityLabel(d.severity),
          message: d.message,
          source: d.source,
          ...(d.code ? { code: d.code } : {}),
        }));

        return {
          content: [
            {
              type: "text" as const,
              text: JSON.stringify(
                {
                  count: formatted.length,
                  diagnostics: formatted,
                },
                null,
                2,
              ),
            },
          ],
        };
      }

      case "get_output": {
        const id = args!.id as string;
        const lines = (args?.lines as number) ?? 50;
        const output = manager.getOutput(id, lines);
        return {
          content: [
            {
              type: "text" as const,
              text: output.join("\n") || "(no output yet)",
            },
          ],
        };
      }

      case "clear_diagnostics": {
        const id = args!.id as string;
        manager.clearDiagnostics(id);
        return {
          content: [
            {
              type: "text" as const,
              text: `Diagnostics cleared for watcher "${id}".`,
            },
          ],
        };
      }

      default:
        return {
          content: [
            {
              type: "text" as const,
              text: `Unknown tool: ${name}`,
            },
          ],
          isError: true,
        };
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      content: [{ type: "text" as const, text: `Error: ${message}` }],
      isError: true,
    };
  }
});

// Graceful shutdown
process.on("SIGINT", () => {
  manager.stopAll();
  process.exit(0);
});
process.on("SIGTERM", () => {
  manager.stopAll();
  process.exit(0);
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // Server is now running on stdio
}

main().catch((err) => {
  console.error("Fatal error:", err);
  manager.stopAll();
  process.exit(1);
});
