import { spawn, ChildProcess } from "child_process";
import { createParser } from "./parsers/index.js";
import { Diagnostic, OutputParser, WatcherConfig, WatcherState } from "./types.js";

const MAX_OUTPUT_BUFFER_LINES = 500;

export class WatcherManager {
  private watchers = new Map<string, WatcherInstance>();

  start(config: WatcherConfig): WatcherState {
    if (this.watchers.has(config.id)) {
      throw new Error(`Watcher "${config.id}" is already running`);
    }
    const instance = new WatcherInstance(config);
    instance.start();
    this.watchers.set(config.id, instance);
    return instance.getState();
  }

  stop(id: string): WatcherState {
    const instance = this.watchers.get(id);
    if (!instance) {
      throw new Error(`No watcher with id "${id}"`);
    }
    instance.stop();
    const state = instance.getState();
    this.watchers.delete(id);
    return state;
  }

  stopAll(): void {
    for (const [id, instance] of this.watchers) {
      instance.stop();
      this.watchers.delete(id);
    }
  }

  getState(id: string): WatcherState {
    const instance = this.watchers.get(id);
    if (!instance) {
      throw new Error(`No watcher with id "${id}"`);
    }
    return instance.getState();
  }

  getDiagnostics(id?: string): Diagnostic[] {
    if (id) {
      const instance = this.watchers.get(id);
      if (!instance) {
        throw new Error(`No watcher with id "${id}"`);
      }
      return instance.getDiagnostics();
    }
    // All diagnostics from all watchers
    const all: Diagnostic[] = [];
    for (const instance of this.watchers.values()) {
      all.push(...instance.getDiagnostics());
    }
    return all;
  }

  clearDiagnostics(id: string): void {
    const instance = this.watchers.get(id);
    if (!instance) {
      throw new Error(`No watcher with id "${id}"`);
    }
    instance.clearDiagnostics();
  }

  listWatchers(): WatcherState[] {
    return Array.from(this.watchers.values()).map((w) => w.getState());
  }

  has(id: string): boolean {
    return this.watchers.has(id);
  }

  getOutput(id: string, lines?: number): string[] {
    const instance = this.watchers.get(id);
    if (!instance) {
      throw new Error(`No watcher with id "${id}"`);
    }
    return instance.getOutput(lines);
  }
}

class WatcherInstance {
  private config: WatcherConfig;
  private process: ChildProcess | null = null;
  private parser: OutputParser;
  private diagnostics: Diagnostic[] = [];
  private outputBuffer: string[] = [];
  private startedAt: Date | null = null;
  private lastUpdated: Date | null = null;
  private exitCode: number | null = null;

  constructor(config: WatcherConfig) {
    this.config = config;
    this.parser = createParser(config.parser, config.regexPatterns);
  }

  start(): void {
    const shell = this.config.shell ?? "/bin/sh";
    this.process = spawn(shell, ["-c", this.config.command], {
      cwd: this.config.cwd ?? process.cwd(),
      env: { ...process.env, ...this.config.env },
      stdio: ["ignore", "pipe", "pipe"],
    });

    this.startedAt = new Date();
    this.exitCode = null;

    const handleData = (data: Buffer) => {
      const text = data.toString();
      // Store raw output
      const lines = text.split("\n");
      for (const line of lines) {
        if (line) {
          this.outputBuffer.push(line);
          if (this.outputBuffer.length > MAX_OUTPUT_BUFFER_LINES) {
            this.outputBuffer.shift();
          }
        }
      }
      // Parse for diagnostics
      const newDiags = this.parser.parse(text, this.config.id);
      if (newDiags.length > 0) {
        this.diagnostics.push(...newDiags);
        this.lastUpdated = new Date();
      }
    };

    this.process.stdout?.on("data", handleData);
    this.process.stderr?.on("data", handleData);

    this.process.on("exit", (code) => {
      this.exitCode = code;
      // Flush remaining parser buffer
      const remaining = this.parser.flush(this.config.id);
      if (remaining.length > 0) {
        this.diagnostics.push(...remaining);
        this.lastUpdated = new Date();
      }
    });

    this.process.on("error", (err) => {
      this.outputBuffer.push(`[watch-command-lsp] Process error: ${err.message}`);
      this.exitCode = -1;
    });
  }

  stop(): void {
    if (this.process && this.exitCode === null) {
      this.process.kill("SIGTERM");
      // Force kill after 5s
      setTimeout(() => {
        if (this.process && this.exitCode === null) {
          this.process.kill("SIGKILL");
        }
      }, 5000);
    }
  }

  getDiagnostics(): Diagnostic[] {
    return [...this.diagnostics];
  }

  clearDiagnostics(): void {
    this.diagnostics = [];
    this.parser.reset();
  }

  getOutput(lines?: number): string[] {
    if (lines) {
      return this.outputBuffer.slice(-lines);
    }
    return [...this.outputBuffer];
  }

  getState(): WatcherState {
    return {
      config: this.config,
      pid: this.process?.pid ?? null,
      running: this.process !== null && this.exitCode === null,
      diagnostics: [...this.diagnostics],
      outputBuffer: [...this.outputBuffer],
      startedAt: this.startedAt,
      lastUpdated: this.lastUpdated,
      exitCode: this.exitCode,
    };
  }
}
