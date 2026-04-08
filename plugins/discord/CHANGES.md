# Changes from upstream

This plugin is derived from Anthropic's official
[Discord channel plugin](https://github.com/anthropics/claude-code/tree/main/packages/channel-discord)
(Apache-2.0). The following modifications were made for use in the `ai-mktpl`
marketplace:

- **Bot message support** -- the upstream server ignores all bot-authored
  messages. This fork processes messages from other bots, which enables
  multi-agent relay scenarios (e.g. a bridge bot forwarding from another
  platform). Messages from the bot's own user ID are still ignored to prevent
  self-loops.
- **Self-message guard** -- an explicit check against the bot's own user ID
  (`client.user.id`) replaces the blanket `message.author.bot` filter, so only
  the bot's own messages are dropped.
