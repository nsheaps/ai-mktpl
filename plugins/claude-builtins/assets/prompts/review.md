Review target: GitHub pull request `${PR}`

Gather this target's diff with (instead of any local `git diff`):

1. `gh pr view ${PR} --json title,body,author,baseRefName,headRefName,state,additions,deletions,changedFiles,labels` for context
2. `gh pr diff ${PR}`

Additional instructions from the user: ${ARGS}

Analyze the changes and provide a thorough code review that includes:

- An overview of what the PR does
- Analysis of code quality and style
- Specific suggestions for improvements
- Any potential issues or risks

Keep your review concise but thorough. Focus on:

- Code correctness
- Following project conventions
- Performance implications
- Test coverage
- Security considerations

Format your review with clear sections and bullet points.
