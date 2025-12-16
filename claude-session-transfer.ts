#!/usr/bin/env npx ts-node
/**
 * Claude Code Session Transfer Prototype
 *
 * This script demonstrates how to transfer a local CLI session to Claude Code Web
 * using the Sessions API discovered from decompiling the Claude Code binary.
 *
 * DISCLAIMER: This is a reverse-engineered prototype. The API is undocumented
 * and may change without notice. Use at your own risk.
 *
 * Prerequisites:
 * - Claude Code installed and authenticated with OAuth (claude.ai account)
 * - Node.js 18+ with ts-node
 *
 * Usage:
 *   npx ts-node claude-session-transfer.ts <local-session-id> [--create-new]
 */

import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';
import { randomUUID } from 'crypto';

// Types based on reverse-engineered session format
interface SessionMessage {
  parentUuid: string | null;
  isSidechain: boolean;
  userType: string;
  cwd: string;
  sessionId: string;
  version: string;
  gitBranch?: string;
  agentId?: string;
  type: 'user' | 'assistant' | 'queue-operation';
  message?: {
    role: 'user' | 'assistant';
    content: string | ContentBlock[];
    model?: string;
    id?: string;
  };
  uuid: string;
  timestamp: string;
  requestId?: string;
  toolUseResult?: string;
}

interface ContentBlock {
  type: 'text' | 'tool_use' | 'tool_result' | 'thinking';
  text?: string;
  thinking?: string;
  id?: string;
  name?: string;
  input?: unknown;
  content?: string;
  is_error?: boolean;
  tool_use_id?: string;
}

interface WebSessionEvent {
  uuid: string;
  session_id: string;
  type: 'user' | 'assistant';
  parent_tool_use_id: string | null;
  message: {
    role: 'user' | 'assistant';
    content: string | ContentBlock[];
  };
}

interface SessionContext {
  sources: Array<{
    type: 'git_repository';
    url: string;
    revision?: string;
  }>;
  outcomes?: Array<{
    type: 'git_repository';
    git_info?: {
      branches: string[];
    };
  }>;
}

// Configuration - discovered from binary analysis
const CONFIG = {
  BASE_API_URL: 'https://api.anthropic.com',
  ANTHROPIC_VERSION: '2023-06-01',
  SESSIONS_PATH: path.join(process.env.HOME || '~', '.claude', 'projects'),
  AUTH_PATH: path.join(process.env.HOME || '~', '.claude', '.credentials'),
};

/**
 * Get OAuth credentials from Claude Code's credential store
 */
async function getOAuthCredentials(): Promise<{ accessToken: string; orgUUID: string } | null> {
  // Try to read from credential store
  const credPaths = [
    path.join(process.env.HOME || '~', '.claude', '.credentials'),
    path.join(process.env.HOME || '~', '.config', 'claude', 'credentials.json'),
  ];

  for (const credPath of credPaths) {
    if (fs.existsSync(credPath)) {
      try {
        const content = fs.readFileSync(credPath, 'utf-8');
        const creds = JSON.parse(content);

        // Handle different credential formats
        if (creds.claudeAiOauth) {
          return {
            accessToken: creds.claudeAiOauth.accessToken,
            orgUUID: creds.claudeAiOauth.organizationUuid || '',
          };
        }
        if (creds.accessToken) {
          return {
            accessToken: creds.accessToken,
            orgUUID: creds.organizationUuid || '',
          };
        }
      } catch (e) {
        console.error(`Failed to parse ${credPath}:`, e);
      }
    }
  }

  // Check environment variables
  if (process.env.CLAUDE_CODE_OAUTH_TOKEN) {
    return {
      accessToken: process.env.CLAUDE_CODE_OAUTH_TOKEN,
      orgUUID: process.env.CLAUDE_ORG_UUID || '',
    };
  }

  return null;
}

/**
 * Build headers for Sessions API requests
 */
function buildHeaders(accessToken: string, orgUUID: string): Record<string, string> {
  return {
    'Authorization': `Bearer ${accessToken}`,
    'Content-Type': 'application/json',
    'anthropic-version': CONFIG.ANTHROPIC_VERSION,
    'x-organization-uuid': orgUUID,
  };
}

/**
 * Read and parse a local session file
 */
function readLocalSession(sessionId: string): SessionMessage[] {
  // Find the session file
  const projectDirs = fs.readdirSync(CONFIG.SESSIONS_PATH);

  for (const dir of projectDirs) {
    const sessionFile = path.join(CONFIG.SESSIONS_PATH, dir, `${sessionId}.jsonl`);
    if (fs.existsSync(sessionFile)) {
      const content = fs.readFileSync(sessionFile, 'utf-8');
      const lines = content.trim().split('\n');

      return lines
        .map(line => {
          try {
            return JSON.parse(line) as SessionMessage;
          } catch {
            return null;
          }
        })
        .filter((msg): msg is SessionMessage => msg !== null);
    }
  }

  throw new Error(`Session ${sessionId} not found in ${CONFIG.SESSIONS_PATH}`);
}

/**
 * Convert local session messages to web API event format
 */
function convertToWebEvents(messages: SessionMessage[]): WebSessionEvent[] {
  const events: WebSessionEvent[] = [];

  for (const msg of messages) {
    // Skip non-message entries
    if (msg.type === 'queue-operation' || !msg.message) continue;

    // Skip thinking blocks for now (they're internal)
    const content = msg.message.content;
    if (Array.isArray(content)) {
      const hasOnlyThinking = content.every(
        (block: ContentBlock) => block.type === 'thinking'
      );
      if (hasOnlyThinking) continue;
    }

    events.push({
      uuid: msg.uuid || randomUUID(),
      session_id: msg.sessionId,
      type: msg.type as 'user' | 'assistant',
      parent_tool_use_id: null,
      message: {
        role: msg.message.role,
        content: msg.message.content,
      },
    });
  }

  return events;
}

/**
 * Create a new web session
 */
async function createWebSession(
  accessToken: string,
  orgUUID: string,
  title: string,
  repoUrl?: string
): Promise<string> {
  const headers = buildHeaders(accessToken, orgUUID);

  const sessionContext: SessionContext = {
    sources: [],
  };

  if (repoUrl) {
    sessionContext.sources.push({
      type: 'git_repository',
      url: repoUrl,
    });
  }

  // Note: Session creation endpoint may not be publicly accessible
  // This is a best-guess based on the Sessions API pattern
  const response = await fetch(`${CONFIG.BASE_API_URL}/v1/sessions`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      title,
      session_context: sessionContext,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to create session: ${response.status} ${error}`);
  }

  const data = await response.json();
  return data.id;
}

/**
 * Upload events to a web session
 */
async function uploadEvents(
  accessToken: string,
  orgUUID: string,
  sessionId: string,
  events: WebSessionEvent[]
): Promise<boolean> {
  const headers = buildHeaders(accessToken, orgUUID);

  const response = await fetch(
    `${CONFIG.BASE_API_URL}/v1/sessions/${sessionId}/events`,
    {
      method: 'POST',
      headers,
      body: JSON.stringify({ events }),
    }
  );

  if (!response.ok) {
    const error = await response.text();
    console.error(`Failed to upload events: ${response.status} ${error}`);
    return false;
  }

  return true;
}

/**
 * List existing web sessions
 */
async function listWebSessions(
  accessToken: string,
  orgUUID: string
): Promise<Array<{ id: string; title: string; status: string }>> {
  const headers = buildHeaders(accessToken, orgUUID);

  const response = await fetch(`${CONFIG.BASE_API_URL}/v1/sessions`, {
    method: 'GET',
    headers,
  });

  if (!response.ok) {
    throw new Error(`Failed to list sessions: ${response.status}`);
  }

  const data = await response.json();
  return data.data || [];
}

/**
 * Get git remote URL from current directory
 */
function getGitRemoteUrl(): string | null {
  try {
    const { execSync } = require('child_process');
    const remote = execSync('git remote get-url origin', { encoding: 'utf-8' }).trim();
    return remote;
  } catch {
    return null;
  }
}

/**
 * Main function
 */
async function main() {
  console.log('🚀 Claude Code Session Transfer Prototype\n');
  console.log('⚠️  WARNING: This uses reverse-engineered APIs that may change.\n');

  // Parse arguments
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.log('Usage: npx ts-node claude-session-transfer.ts <session-id> [--create-new]');
    console.log('\nOptions:');
    console.log('  <session-id>   Local session ID to transfer');
    console.log('  --create-new   Create new web session (otherwise lists existing)');
    console.log('  --list         List local sessions');
    console.log('\nExample:');
    console.log('  npx ts-node claude-session-transfer.ts c958eaa2-954d-48a8-b2e0-2251bd5959c6');
    process.exit(1);
  }

  // List local sessions
  if (args[0] === '--list') {
    console.log('📁 Local Sessions:\n');
    const projectDirs = fs.readdirSync(CONFIG.SESSIONS_PATH);

    for (const dir of projectDirs) {
      const dirPath = path.join(CONFIG.SESSIONS_PATH, dir);
      const files = fs.readdirSync(dirPath).filter(f => f.endsWith('.jsonl'));

      if (files.length > 0) {
        console.log(`  ${dir}/`);
        for (const file of files) {
          const sessionId = file.replace('.jsonl', '');
          const filePath = path.join(dirPath, file);
          const stats = fs.statSync(filePath);
          console.log(`    - ${sessionId} (${(stats.size / 1024).toFixed(1)} KB)`);
        }
      }
    }
    process.exit(0);
  }

  const sessionId = args[0];
  const createNew = args.includes('--create-new');

  // Get OAuth credentials
  console.log('🔑 Getting OAuth credentials...');
  const creds = await getOAuthCredentials();

  if (!creds) {
    console.error('❌ No OAuth credentials found.');
    console.error('   Please authenticate with: claude login');
    console.error('   Or set CLAUDE_CODE_OAUTH_TOKEN environment variable.');
    process.exit(1);
  }
  console.log('✅ Found credentials\n');

  // Read local session
  console.log(`📖 Reading local session: ${sessionId}...`);
  let messages: SessionMessage[];
  try {
    messages = readLocalSession(sessionId);
    console.log(`✅ Found ${messages.length} messages\n`);
  } catch (e) {
    console.error(`❌ ${e}`);
    process.exit(1);
  }

  // Convert to web format
  console.log('🔄 Converting to web format...');
  const events = convertToWebEvents(messages);
  console.log(`✅ Converted ${events.length} events\n`);

  // Get git info
  const repoUrl = getGitRemoteUrl();
  if (repoUrl) {
    console.log(`📦 Detected repository: ${repoUrl}\n`);
  }

  if (createNew) {
    // Create new web session
    console.log('🌐 Creating new web session...');
    try {
      const webSessionId = await createWebSession(
        creds.accessToken,
        creds.orgUUID,
        `CLI Transfer: ${sessionId.substring(0, 8)}`,
        repoUrl || undefined
      );
      console.log(`✅ Created web session: ${webSessionId}\n`);

      // Upload events
      console.log('⬆️  Uploading events...');
      const success = await uploadEvents(
        creds.accessToken,
        creds.orgUUID,
        webSessionId,
        events
      );

      if (success) {
        console.log('✅ Events uploaded successfully!\n');
        console.log(`🔗 Open in browser: https://claude.ai/code/${webSessionId}`);
      } else {
        console.error('❌ Failed to upload events');
        process.exit(1);
      }
    } catch (e) {
      console.error(`❌ ${e}`);
      console.error('\nNote: Session creation may require additional permissions.');
      console.error('The Sessions API may not support direct session creation.');
      process.exit(1);
    }
  } else {
    // List existing web sessions
    console.log('🌐 Fetching existing web sessions...');
    try {
      const sessions = await listWebSessions(creds.accessToken, creds.orgUUID);
      console.log(`✅ Found ${sessions.length} web sessions:\n`);

      for (const session of sessions.slice(0, 10)) {
        console.log(`  - ${session.id}: ${session.title} [${session.status}]`);
      }

      if (sessions.length > 10) {
        console.log(`  ... and ${sessions.length - 10} more`);
      }

      console.log('\n💡 To upload to a session, use:');
      console.log(`   CLAUDE_WEB_SESSION_ID=<id> npx ts-node claude-session-transfer.ts ${sessionId} --upload`);
    } catch (e) {
      console.error(`❌ ${e}`);
    }
  }

  // Print event preview
  console.log('\n📋 Event Preview (first 3):');
  console.log('─'.repeat(60));
  for (const event of events.slice(0, 3)) {
    const content = typeof event.message.content === 'string'
      ? event.message.content.substring(0, 100)
      : JSON.stringify(event.message.content).substring(0, 100);
    console.log(`[${event.type}] ${content}...`);
  }
  console.log('─'.repeat(60));
}

// Run
main().catch(console.error);
