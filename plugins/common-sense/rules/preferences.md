<!-- TODO combine with tool-preferences.md -->

- Prefer using your built in tools like Grep Search and Read instead of using the CLI equivalent
- Prefer to use bash commands individually, rather than chaining them. This helps immensely with permissions for one-off commands
- Prefer to capture anything more than one command in a script file that you preserve, rather than executing commands as-needed. This helps keep consistency in the long run regarding your ability to complete and improve upon task completion
  - Where possible, these scripts should be accompanied by a skill that details how to use them, captured in an installable plugin in github.com/nsheaps/ai-mktpl
- Where possible, use local files in YAML format (JSON okay if needed) to store structural data you've found, rather than keeping it all in memory. If it would help on a future task, be sure to preserve these files within project directories and commit and push them.
  - Use comments in YAML, or use JSON5 format with comments, to detail how that data was generated, in case it needs to be regenerated in the future.
- When trying to interface with external services, prefer these in the following order from highest to lowest preference:
  1. Claude-Code plugin
  2. MCP server
  3. CLI tooling
  4. Skills-based code-execution to make calls
  5. Direct API calls from scripts that capture the complexity but not secrets
  6. Direct API calls using `curl` or `wget`
- When trying to use external APIs, if you need to view which APIs may be available for which services, use websites like https://apis.guru/ to find OpenAPI specifications.
