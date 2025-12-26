# Mega-Merge Task Prompt

This file contains the original task prompt for reference during iterative improvements.

## Original Task

Make a new branch, dev/claude, and merge together all open branches/PRs into one megabranch. In that branch, include PULL_REQUEST_BODY.md including a good pull request description. Once merging together, investigate all the changes made in that branch compared to main, clean it up, improve it to the best of your ability. At the end of improving it, evaluate it again, update the PR description, give yourself a review (use the prompt in one of the github actions workflows as a good example), and repeat until you don't think there's any more improvements to be made. Do not introduce any additional complexity or features other than what already exists in the branches, your goal is to merge them all together in a way that solidifies the patterns in the repo in such a way that we can continue to iterate from these. The actual plugins and skills do not need to work, but the github actions workflows do. Make sure in a PR that the workflows run in a way that can validate the changes, but only take effect on the main branch (including proposed version bumps per plugin via posting a comment (that is updated if already exists, but created if not, never duplicated)). Use these workflows in the PR (which may need an additional, later trigger) to help validate your changes, as well as abstracting the logic to scripts that can be shared between CI workflows and local validation (triggering using a justfile). This will definitely be an iterative process, do not lose this specific prompt, also save it to file, and every re-evaluation, explicitly re-state this prompt to remind yourself of the goals. When you hit a stopping point (such as the inability to create a PR), I will worry about re-triggering you, but be sure to give me a good prompt that I can use in a comment on the PR to continue your work (like @claude, please read ....prompt.md and continue the work on this branch), and a link to make the PR, pre-filled with your body/title. Do whatever research you need to help you accomplish the task, but especially review documentation at the following sites, as well as using the claude-code-guide agent to help you in configuring the repo properly. A side-quest goal to document but not solve here, would be to move prompts that are shared between ci workflows, etc, into files outside of the CI workflows, potentially with templating for added support for things like the !`bash command` syntax.

## Key Goals

1. **Merge all open branches/PRs** into a single `dev/claude` megabranch
2. **Create PULL_REQUEST_BODY.md** with comprehensive description
3. **Clean up and improve** the merged code
4. **Ensure GitHub Actions workflows work** - validate changes in PR, but only take effect on main
5. **Abstract logic to shared scripts** - justfile for local, scripts for CI
6. **Self-review and iterate** until no more improvements needed
7. **Document side-quest**: Moving shared prompts to external files with templating support

## Constraints

- Do NOT introduce additional complexity or features beyond what exists in branches
- Solidify patterns in the repo for future iteration
- Plugins/skills don't need to work, but GitHub Actions workflows do
- Version bumps should be posted as comments (update if exists, never duplicate)

## Continuation Prompt

When hitting a stopping point, use this to continue:

```
@claude, please read MERGE_TASK_PROMPT.md and continue the work on this branch. Review your previous changes, evaluate the current state, and continue iterating until the merge is complete and clean.
```

## Side-Quest Documentation

### Goal: Externalize CI Prompts

Move prompts that are shared between CI workflows into external files. Consider:
- Templating support for dynamic content
- Support for `!bash command` syntax for dynamic values
- Shared prompt files that can be referenced by multiple workflows
