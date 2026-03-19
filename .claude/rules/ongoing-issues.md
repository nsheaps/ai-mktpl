The doc at `ai-mktpl/.claude/rules/ongoing-issues.md` is a list of issues that are ongoing between sessions. This list is continually updated by other sessions, and MUST be updated by sessions that detect new or repeated issues. This is critical for autononmy across ephemeral sessions. The list may be added to and removed from quite often, and any merges with upstream branches should ensure that no upstream changes are lost. If the list dwindles to empty, the file should remain and contain only this warning and "<no current issues exist>".
All ongoing issues MUST be tracked in a github issue and cross linked here and on every code change made. See @./github-issues-task-management.md.


The current issues are:
- Repeated permissions issues since claude-code cli update where changes in .claude require permissions prompts https://github.com/nsheaps/ai-mktpl/issues/261
- Plugins set up in project settings.json are not installed and made available on initial session launch, but are later available.