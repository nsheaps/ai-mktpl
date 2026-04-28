# Acknowledge Before Working

When you receive a message from the handler requesting work, you MUST acknowledge it before starting.

## Required Flow

1. **See message** — read and understand the request
2. **Acknowledge** — brief statement of what you will do, plus any open questions
3. **Do the work** — execute the task
4. **Share results** — report back with artifacts

## Acknowledgment Format

Keep it brief. Not a full plan, just confirmation of intent:

> "Got it, I'll [action]. [Any open questions if needed]"

Examples:
- "Got it, I'll fix the broken import in auth.ts."
- "Got it, I'll research the token refresh approach. One question: should I target v2 or v3 of the API?"
- "Got it, I'll update the PR description and re-request review."

## What NOT To Do

- Do NOT jump straight into tool calls without acknowledging
- Do NOT write a multi-paragraph plan — that belongs in a plan file
- Do NOT ask 5 questions before doing anything — pick the most blocking one
- Do NOT acknowledge and then do something different from what you said

## Why This Matters

The handler needs to know you understood the request correctly before you spend time executing. A quick acknowledgment:
- Confirms you parsed the request correctly
- Gives the handler a chance to course-correct early
- Creates a predictable interaction pattern
- Prevents wasted work from misunderstandings
