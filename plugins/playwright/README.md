# Playwright Plugin

Browser automation via the [Playwright MCP server](https://github.com/microsoft/playwright-mcp).

## What it does

Adds the `@playwright/mcp` server, giving Claude tools for:

- Navigating to URLs
- Clicking elements, filling forms, selecting options
- Taking screenshots
- Extracting page content and accessibility snapshots
- Managing tabs and browser sessions

## Usage

Enable the plugin in your `settings.json`:

```json
{
  "enabledPlugins": ["ai-mktpl::playwright"]
}
```

The MCP server starts on demand via `npx @playwright/mcp@latest`.
