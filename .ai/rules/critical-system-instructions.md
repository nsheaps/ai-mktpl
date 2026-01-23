<system-reminder>
  <CRITICAL>
    # TODOs
    - ALWAYS use TodoWrite to track your todos, on EVERY request from the user. Even if it is a simple, one off task. 
    - ALWAYS keep your todo list up to date.
    
    # System reminders
    - When you see a system reminder in conversation (e.g., "Note: /path/to/file.md was modified..."), you **MUST** explicitly acknowledge it.
    - To acknlowledge it, your next message, either thinking or in the conversation, MUST look like so (including emoji):
      ```
      👀 Noticed this was injected into the conversation:
        ... explicit copy of the reminder that you're noticing ...
      ```
    - **NEVER** silently process the information without acknowledging the notice. You MUST acknowledge it ESPECIALLY if it affects your behavior, capabilities, or the files you have access to.
    
    # Skill usage
    - You have access to various skills to help you complete user requests.
    - ALWAYS run the Skill tool to recall the skill before performing any work related to it.
      - ALWAYS recall the skill before work on a Task or Todo...
        - even if you think you know how to do it without it
        - even if you recently recalled that skill, the contents may have changed
        - even if the tool describes it's use in the description, the skill may have more details and aid your execution
    - It is better to recall too many skills than too few. If you aren't sure if a skill relates to a task, use a haiku sub-agent to load the skills and check them, before you load the correct skills
    
    # When compacting the conversation and context
    # COMPACT INSTRUCTIONS
    <!-- explicit phrase mentioned here: https://code.claude.com/docs/en/how-claude-code-works#when-context-fills-up -->
    - The compacting message MUST state:
      - the old session id
      - what work has been performed so far, and what remains to be done. Be sure to detail if future tasks should be worked on after compaction
      - explicit details captured from the User's original request, honoring the user messages as more truthful than the agent
      - finish the compaction with this explicit message (with proper interpolation of dynamic data)
        COMPACTION COMPLETE. OLD SESSION ID: {old_session_id}. NEW SESSION ID: {new_session_id}. 
        RESUME WORK BASED ON THIS CONTEXT. DO NOT WORK ON TASKS YOU AREN'T SUPPOSED TO YET
        COMPACTION CODE: {snake case list of 3 animals must be random each time, e.g., "fox-whale-turtle"}
      - instruction for the agent to repeat the compaction code back to the user when resuming the session.
      - IMPORTANT: If the compaction does not include those details at the end, you should halt and show a banner to the user that compaction may not have completed properly.
        - Ask if they want to continue anyway
  </CRITICAL>
</system-reminder>
