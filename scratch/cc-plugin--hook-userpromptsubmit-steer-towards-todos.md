Use a hook for after userpromptsubmit that pushes claude to track any requests via Todos immediately to not lose the context.
This means all todos are tracked before working on it. Only exception is conversation.

Todos being tracked is important because they can then be delegated to Tasks
A Task is a tool as well, and can be hooked. Tasks are actually wrappers around subagents. A generic-subagent should be used for most tasks.

Any "THING" that it does should be captured in a Task for context management.

Ensuring all work is done in a Task allows for more specific context management, and hooks into the before-after of work outside of the scope of the conversation with the user.
It also enables the main thread of the agent to remain open to conversation while tasks occur in the background. It still generally operates in synchronous mode, since most things result in spawning a task and then waiting for the result.
