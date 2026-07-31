Analyze this Claude Code usage data and suggest improvements.

## CC FEATURES REFERENCE (pick from these for features_to_try):

1. **MCP Servers** — How to use: `claude mcp add <server-name> -- <command>` — Good for: database queries, Slack integration, GitHub issue lookup, connecting to internal APIs
2. **Custom Skills** — How to use: Create `.claude/skills/commit/SKILL.md`, type `/commit` — Good for: repetitive workflows /commit /review /test /deploy /pr
3. **Hooks** — How to use: Add to `.claude/settings.json` under "hooks" — Good for: auto-formatting, type checks, enforcing conventions
4. **Headless Mode** — How to use: `claude -p "fix lint errors" --allowedTools "Edit,Read,Bash"` — Good for: CI/CD, batch fixes, automated reviews
5. **Task Agents** — How to use: auto-invokes or ask "use an agent to explore X" — Good for: codebase exploration

RESPOND WITH ONLY A VALID JSON OBJECT:

{
  "claude_md_additions": [
    {
      "addition": "The instruction to add to CLAUDE.md",
      "why": "Why this helps, referencing the user's data",
      "prompt_scaffold": "A copyable snippet the user can paste into CLAUDE.md"
    }
  ],
  "features_to_try": [
    {
      "feature": "Feature name from the reference above",
      "one_liner": "One sentence on what it does",
      "why_for_you": "Why it fits this user's patterns",
      "example_code": "A concrete command or config snippet"
    }
  ],
  "usage_patterns": [
    {
      "title": "Short title",
      "suggestion": "The pattern to try",
      "detail": "1-2 sentences of detail",
      "copyable_prompt": "A prompt the user can copy and paste"
    }
  ]
}

IMPORTANT for claude_md_additions: PRIORITIZE instructions that appear MULTIPLE TIMES in the user data. If user told Claude the same thing in 2+ sessions (e.g., 'always run tests', 'use TypeScript'), that's a PRIME candidate - they shouldn't have to repeat themselves.

IMPORTANT for features_to_try: Pick 2-3 from the CC FEATURES REFERENCE above. Include 2-3 items for each category.
