# Sub-Agent Usage

## Reports Must Be Saved to Files

**CRITICAL:** When using sub-agents to produce reports or analyses:

1. The sub-agent MUST save its output to a file
2. The main agent reads that file to access the results
3. NEVER have sub-agents return extensive output directly in conversation

**Why:** Returning large responses in conversation creates extreme risk - the conversation becomes unusable and unable to compact properly.
