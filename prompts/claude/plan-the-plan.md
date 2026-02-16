use the Explore agent with haiku and Plan agent with opus to come up with a simple step by step plan to iteratively implement each of these tickets.

This plan itself should not have a plan for each ticket, just a high level plan of how to iteratively work on each step.

In the plan it should detail how to work on the tickets.

- Each should be it's own PR, so each should be it's own branch, using graphite to stack them atop each other.
- Each ticket should be worked on by a sub-agent and each ticket should start with using Explore and Plan agents to come up with a plan for that ticket.
- For each PR, the title must be in conventional commit style, with the ticket number at the end for auto linking.
- For each PR, CI must also pass, and be open in draft with nsheaps as the assignee.
- You should use your plugins and tools to review your code before pushing. Make any noted needed adjustments.
- ALWAYS delegate the review task to a sub-agent and let them launch any other needed sub-agents.
- Use tools and plugins like
  - /review,
  - /review-changes
  - /review-pr
  - /code-review,
  - /pr-comments,
  - agents like the code-simplifier agent, the code-reviewer agent,
  - and any associated skills like /commit.
- PR reviews can be requested after pushing the code by adding the request-review label to the draft PR but err on reviewing your own code first.
- Reviewing should be done with a critical eye factoring the things noted in the claude-code-review workflow, most importantly, simplicity, maintainability, it's adherence to code style and methodology within the repository, and it's adherence to the original plan.

The plan should factor in:

- the project tracking ticket (like linear, jira, github issue) ticket and keeping it up to date
- the wiki docs (like notion or confluence) docs which contain the planning we did for each ticket and technical designs:
  ...
- Documentation, agent rules, and agent skills located within the repo
- the PRs that this change is based off of
- the PR for this ticket and keeping that up to date.

You as the orchestrator should always try to delegate to an agent.
Use a new agent for each ticket and if work needs to be done on that ticket/pr, resume the conversation with that agent.
Also delegate the review tasks
