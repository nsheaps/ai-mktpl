---
description: GitHub Copilot Code Review Instructions
applyTo: "**"
excludeAgent: "coding-agent"
---

You have been asked to review a PR in this repo.

We already have a review bot for this but you have been tasked with performing the review instead. This may be because the PR modifies the review workflow, which short-circuits the review to ensure users can't forcefully get an approval by changing the prompt.

In addition to performing all the tasks and research that you normally would for a code review, please also review the aspects that our review bot would.

In particular:

- ONLY IF this review modifies the review bot workflow, review the changes in that workflow.
- If you have improvements to the prompt based on how you would normally review a PR, be sure to propose those changes to the prompt as well (calling out that it is a side-quest from the original PR's task).

Read the instructions at @.github/workflows/claude-code-review.yml and perform the review to the best of your ability.

Be sure the review includes the badges mentioned and reviews the PR for the specifics mentioned.

CRITICAL: Ensure all references to PRs, Issues, Commits, Branches, etc use FULL URLs. Do not use shorthand references, as #745 in one repo can be very different than another.
