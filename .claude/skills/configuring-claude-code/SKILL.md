---
name: configuring-claude-code
description: |
  Use this skill when making changes to AGENTS.md, CLAUDE.md SKILL.md, .claude folders, either in this project or in ~/.claude/ for configuring Claude code behavior (with settings.json, settings.local.json, CLAUDE.local.md, etc).
  It should be auto-recalled when needing to fetch documentation, or when making changes to those files. Consider using it also when fetching content from the following sites:
   - domain:anthropic.com
   - domain:*.anthropic.com
   - domain:claude.ai
   - domain:*.claude.ai
  This skill may also contain useful information learned about configuring Claude code behavior, using the anthropic agent sdk, the claude code sdk, the claude agent sdk, the claude api, the claude code tool, claude desktop, claude code web, codex, gemini, other ai cli tools/mcp clients, skills, slash commands, agents, sub-agents, rules, plans, prompts, scratch files, documentation, ai orchestration, ai tooling, agentic patterns and platform features and design.
---

> [!NOTE]
> This skill is a living document located at:
>   https://github.com/stainless-api/stainless/.claude/skills/configuring-claude-code/SKILL.md
> It is intended to be used only to capture extra information.
> If using this skill to perform a task and you learn something new, please update this skill to capture that knowledge for future use. Be sure these updates end up pushed to a remote repository so they are not lost.
> It is rare that something is in this skill that isn't added by this branch that has not been validated by others before merging it to the default branch. Sometimes the behaviors change, and the skill may be out of date. Always validate the information here against official documentation when possible. If you find something that is out of date, please update this skill to reflect the current state of affairs. Do not remove information in the same time you change anything, instead add a note about the new information and that the old information is deprecated. Be sure to include references to external sites to back up the deprecation claim.
> When adding information, be sure to include references to official documentation or other sources of truth whenever possible. These are critical to ensuring claims in this document are backed up by reliable sources. However, the addition of claims in this document without sources is acceptable when the information is learned from direct experience and experimentation, especially if added by a human.
>   Make sure references use markdown link format for you to summarize what the link is and hide long urls from the human.
> Always use the configuring-claude-code skill when making changes to claude code configuration files, rules, slash commands, agents, plugins, skills, or settings.
> CRITICAL: Any changes to THIS skill MUST be verified using the claude-code-guide when running code reviews from .github/workflows/claude-code-review.yml
> To test this, the stainless-review-bot[bot] should notice this line and suggest removing it in the code review, and confirm anything that's not in the theories and questions section.

> [!NOTE]
> This document should work as a treasure trove of extra knowledge learned about claude, claude code, and associated AI tooling. It is generally targeted towards claude because the organization (Stainless) primarily uses claude, but may contain useful information about other ai tools as well, especially about how to share the claude configurations with other tools.
> It should not duplicate information found online. Instead, link to the source of truth and why it is relevant.

### Interesting sites

- [Claude Logs](https://claudelog.com)
- [r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/)
- [Anthropic Platform Docs](https://platform.anthropic.com/docs/)
- [Claude Docs](https://claude.ai/docs)
- [Claude Code docs](https://claude.ai/docs/claude-code)
- [Claude Code Github Repo](https://github.com/anthropic/claude-code)
- [Claude Code Github Action Repo](https://github.com/anthropic/claude-code-action)
- https://github.com/dair-ai/Prompt-Engineering-Guide / https://promptingguide.ai/


### You have tools built in to help you.

- You have a sub agent called `claude-code-guide` that can help you find recent documentation about configuring claude code.

### You have tools built by us to help you.

- You have a command called `scripts/claude-diagnostics` which hoists all configs into an archive to be shared
  - Use this generously when asked "Why did you do that?"
  - If asked "Show me your config", point directly to the source instead, ensuring to follow and call out any symlinks.
  - This command can be run either in claude using the REPL `! scripts/claude-diagnostics` syntax or in a regular terminal for the base state.
  - Be cautious about sharing the contents. It may contain secrets, keys, passwords, tokens, personal information, proprietary info, or other sensitive data. Always review before sharing except when sharing directly with a user.

### Theories (we haven't confirmed) and questions (we haven't researched and answered yet)

- How can we share a rule file across projects/the user rules without it appearing twice in the context?
- Does using `run_in_background:true` change how the context is reported to the agent?
- Should you _always_ use `run_in_background:true` for _any_ task so that the main conversation loop stays repsonsive?
  - if you do, is it more difficult to monitor tasks?
  - if you do, claude tends to want to use Bash to tail the output in a random temp folder? Is that an issue only with @nsheaps and his ruleset? (he's asking this question)
    - When it's tailing for output, you have to "interrupt" it for the message to go through.
- Does a task running in the background trigger claude to wake up when it finishes?
- Do all background tasks have an eventual timeout?
  - I've seen them go on for 8+h (@nsheaps)
- Do hidden messages (like system messages) show in the raw conversation logs?
- Is there a way to teleport a local session to the web?
  - @nsheaps was looking into this via decompilation and deobfuscation
  - There's something about syncing to a remote API but neigh impossible to figure out how to trigger the condition. Supposedly something about using `--teleport <url>` where the URL is
- Is there a way for a user to share their claude code web session to another user?
  - The slack app automatically (configurable) shares the session with the whole org, but no buttons to turn on/off?
  - This would make it better when ephemeral agents can teleport the previous session from one instance to another
    - There's some downside to keeping a session going for too long
- Can you get claude to automatically fix anything that's been deprecated after upgrading claude versions?
- Does AskUserQuestion pause execution or can it be run in background?

### Learned behaviors and tips for better performance while using claude code

These are some notes about how certain things work in claude code, to aide in configuring claude code behavior correctly.

- When using `claude-code-guide` agent to look up current documentation and assist with making configuration changes, insist that the agent utilizes upstream documentation with explicit examples and references with links to and excerpts from the documentation. This ensures that your responses are accurate and up to date with the latest documentation, not just made up and hallucinated by the agent, which can sometimes happen on lower intelligence models. If they are not provided, reject the response and ask the agent to try again, insisting on proper references.
- When you send a message, then interrupt it by hitting ESC, the message is sent and does not need to be repeated (though you can hit up to edit it, it will send a second time).
  - Confirmed by testing 2026-01-09 @nsheaps, asked what my last two messages were after interrupting both.
- Best practice from claude docs for shared rules is a symlink inside of a `.claude/rules/` dir. If the same doc appears twice in the rules list, even if symlinked to the same location, the rule will be included twice.
  - Confirmed by testing 2025-11-15 @nsheaps, showed in /context
- Despite no documentation, you can place (agents/commands/rules) in subfolders (and via symlinks) and they will be detected. Slash commands will get a prefix based on the folder name.
  - Confirmed by testing 2025-11-15 @nsheaps
- The bash syntax "\!\`command arg1 arg2 ...\`" (without the \ and ", so ! then `then the command then another`) works in slash commands to get info from them to the agent when the slash command is executed. It saves on token usage because the agent does not need to run a loop to run the command, look at the output for every command listed. Unfortunately it _only_ works in slash commands, not in agents, skills, or rules. However, agents CAN run a slash command by running the tool "SlashCommand:/command-name arg1 arg2 ...", at least when guided to.
  - Confirmed by testing 2025-11-15 @nsheaps
  - References to claude docs needed.
- Despite what the creator of claude code said, Skills and SlashCommands are not the same thing. Skills cannot be invoked by the user using "/skill-name", only slash commands can. Skills are only invoked by agents when they decide to use them (though they can be told to). Claude frequently confuses the two in its selection of which tool to use, and will lean more heavily on Skills. Good news is that Skills don't get directory name modifications and skills by the same name can overwrite previous ones, so you can add a note skill to override a previous one. Sad news is that the built in skills don't have files on disk that you can say "you might be calling the wrong skill/command but if you're sure you want to use this skill, read here instead", so you have to override them blindly.
  - in some ways Skills are like slash commands and code mode on steroids, because claude will auto try to load the skill file and the skill can come with any bit of supporting info including scripts it can iterate on and run as part of the skill.
    - For this reason, skills are generally preferred for a "how to do a thing" vs slash commands for "doing a specific action or process" (eg skill for using source control but a slash command for reviewing a PR)
      - The most powerful thing is a use of both, via a plugin that has a skill that uses supporting documentation and encourangement to use the code and included slash commands.
  - Confirmed by testing 2025-11-15 @nsheaps
  - TODO: use `strings` and other tools to inspect claude binary to dump all builtin commands and skills. Nate's started on it but isn't in a shareable state.
- `run_in_background:true` can be a powerful tool for parallelizing Tasks, but be aware that they are difficult to monitor and use by humans.
- Claude needs to be guided to use TodoWrite and associated tools. It receives hidden prompts when it's been working to encourage it's use, but the user will never see it
- Generally, using one session too long will cause claude to degrade in performance. Best practice is to start a new session for almost every prompt you send.
  - It's ability to continue working can rely heavily on it's ability to retrieve context from previous sessions. It should be guided to also use git history to try and understand it's changes without access to the sessions, and it should keep this in mind when writing commit messages.
  - testing needed @nsheaps
- Claude will absolutely most definitely forget the prompt you sent him.
  - (future thinking @nsheaps): We should have a hook on UserPromptSubmit that saves it into `./.claude/prompts/$sessionId.md`, then use a mini `claude -p --model=haiku 'rename the file to be more descriptive based on it's content'` to rename it to something more useful.
    - it still needs guidance to look there
      - We should do the same with injected guidance to use Explore and Plan and mcp__structuralthinking__* to help figure out how to accomplish requests from users submitted in prompts.
        - Should there be a sub-agent for relevant skill finder to help preserve the context of the outer agent trying to iterate through them all? This agent could also update the description to help make recall better.
    - Same thing can happen with **WHAT** it did. @nsheaps noted that he requested it make a script to programmatically update one file with the contents of another based on rules. It made the script, then forgot it existed and manually updated the file using the _inverse_ criteria (even on opus).
- environment variables from settings.local.json will be evaluated before hooks are run, letting you use env vars to enable local feature flags to gate functionality in claude's configs
- Bash variable substitution works in settings.json attribution fields. Example: `${CLAUDE_PROJECT_DIR/$HOME/~}` correctly replaces $HOME with ~ in the path.
  - Confirmed by testing 2026-01-10 @nsheaps in ai-agent-henry repo
- Almost everything dynamic except actual messages and other info in the context in the conversation are tool use. That includes the use of SlashCommands, Skills, Agents (which are really just the Task tool with a special prompt).
  - which means conversation logs can tell you how often certain things are being used. There's no other good metrics interface.
    - we need to build something that can automatically track these, perhaps via a proxy that can bubble it back to datadog
    - we need to build an agent that can analyze chat logs (either claude code or other agent output like that from guesserv3) and find ways to improve upon the rules/guidance, or the skills/agents/commands available to the agent.
      - In theory, using a bunch of skills to do a single task is bad
      - Having everything in rules is also bad. Skills need to be used.
      - Sometimes an agent will use a skill, and then try to do something (maybe within the following 6 turns) and fail. In theory, that is a behavior that can be improved upon. The improvement may be a configuration/permissions change, rather than an update to rules/skills/agents/commands.
- Claude will put more emphasis on following the specified behaviors in the beginning and end of the context window. This is part of what makes the system prompt and rules files so powerful. However, if something becomes monotonous or noisy, such as a reminder from a hook, it may "learn" to ignore it rather than following it's advice. This gets further reinforced if the agent things and starts saying things like "The reminder is annoying and I will ignore it"
  - Spotted in research blog post and personal experience @nsheaps
- when running in bypass permissions mode, claude's messages to the user will get lost in the shuffle, especially since there will be no pauses for permission requests. Guide claude to use AskUserQuestion for ANY information directed at the user so they have to confirm that they've seen it
