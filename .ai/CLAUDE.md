This folder essentially gets synced to ~/.ai for consistent pathing
Then automation ensures everything in:
- `.ai/rules/` gets symlinked to `$HOME/.claude/rules/`

Automation also
- Finds symlinks in that folder that no longer reference actual files and removes them.

## Why rules, why here?

Rules cannot be included as part of plugins. The closest you can come is an MCP server that overloads the use of tool fields to inject it into the prompt.

Generally these are behaviors you want across the entire organization. Skills are not the same, they capture the HOW to do things. Behaviors capture the WHEN to do things.

TODO: Consider a plugin that comes along with this
An mcp server should be useable to perform this automation
And a plugin can add hooks that help guide when to use certain skills or reference particular rules or documents.

TODO: Claude isn't reading from here for now, so don't do this.