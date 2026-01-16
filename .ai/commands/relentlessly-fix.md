---
argument-hint: [pr(s) to review] OR [instructions for what to relentlessly attempt to do]
description: |
  Keep trying to fix a PR until it passes in CI (or there is a valid reason it cannot) and is self-reviewed thoroughly.
model: claude-4-5-opus
---
- If no PR to review is provided, assume the current branch has an open PR and use that. If you cannot find it, ask the user.
- Use /pr-comments /pr-review-toolkit:* /review /code-review:code-review and any other tools. Fetch the comments from the mentioned PR on the remote.
- Use Explore and Plan agents to plan your next move. 
- Always use sub-agents to execute on Todo's and Tasks. 
- Use TodoWrite judiciously and update it to include details that help you complete your task.
- Make sure your branch is up to date with the latest main when you push, but before requesting review.
- The PR must be passing in CI for you to be complete.
  - ALWAYS attempt to run any validations locally first before pushing changes. This is much faster than pushing and waiting.
  - CI may sometimes function differently than local. This is unintentional. If CI fails when local passes, investigate the difference and fix it, erring on adding more coverage to match CI behavior. Do not add behavior to CI that would cause failures unrelated to the changes on this branch.
- Wrap your entire task in a /ralph-loop:*, using /ralph-loop:help to understand what it is before proceeding. 
  - Once you hit a stopping point and are waiting for CI to pass, re-run your code/PR review skills/tools/commands/agents and iteratively fix any additional issues that come up
- If you require checking out multiple branches, create git worktrees in an appropriate folder within /tmp.
  - Utilize gh to compare branches using the gh api where possible to avoid unnecessary checkouts.

Please fix the PR that is open for this branch.
Keep iterating until the CI is all passing, or there is a valid reason that you are unable to make it pass.
Keep changes contained to the branch for the requested PR, and changes must be relevant (or deemed okay by a human) to the goal of the PR. Do not change other code unrelated to the PR in order to make CI pass, instead make sure the user is aware and attempt to keep the branch up to date with the default branch (`main`) in order to resolve those things.
