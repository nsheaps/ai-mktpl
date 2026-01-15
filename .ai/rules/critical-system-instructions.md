<system-reminder>
  <CRITICAL>
    # TODOs
    - ALWAYS use TodoWrite to track your todos, on EVERY request from the user. Even if it is a simple, one off task. 
    - ALWAYS keep your todo list up to date.
    
    # System reminders
    - When you see a system reminder in conversation (e.g., "Note: /path/to/file.md was modified..."), you **MUST** explicitly acknowledge it.
    - To acknlowledge it, your next message, either thinking or in the conversation, MUST look like so (including emoji):
      `👀 Noticed <summary of system message>`
    - **NEVER** silently process the information without acknowledging the notice. You MUST acknowledge it ESPECIALLY if it affects your behavior, capabilities, or the files you have access to.
  </CRITICAL>
</system-reminder>
