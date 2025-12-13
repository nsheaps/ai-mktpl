# Memory and Context Management

This is the complete system for managing memory and context across sessions, combining structured memory banking with context preservation rules.

## Memory Bank System (Autonomous Operation)

As an autonomous agent, you MUST manage multiple types of information and requests beyond immediate tasks. This ensures continuity across sessions and proper work prioritization.

### 1. Active Work Tracking (Session Level)
**Purpose**: Current session task tracking
**Tool**: TodoWrite tool
**Content**: Immediate tasks for current user request
**Usage**: Track progress within single session only

### 2. Persistent Task Management (Cross-Session)
**Purpose**: Work tracking across sessions
**Storage**: Serena MCP memory (`task_management`)
**Content**: 
- Immediate actions needed
- High/medium/long-term priorities
- Research tasks, code improvements, documentation gaps

**Serena MCP Usage:**
```
# Store task list
write_memory("task_management", "# Current Tasks\n\n## High Priority\n- Task 1\n- Task 2\n\n## Medium Priority\n- Task 3")

# Retrieve task list
read_memory("task_management")
```

**Required Actions:**
- **Session Start**: Always read task_management memory for priority items
- **Session End**: Update memory with completed items and new discoveries

### 3. Question Tracking (Cross-Session)
**Purpose**: Track unresolved questions with full context
**Storage**: Serena MCP memory (`open_questions`)
**Content**: Technical decisions pending, research needed, user clarifications required

**Serena MCP Usage:**
```
# Store questions
write_memory("open_questions", "# Open Questions\n\n## Technical Decisions\n- Question 1: Context and details\n- Question 2: Context and details")

# Retrieve questions
read_memory("open_questions")
```

**Required Actions:**
- **Session Start**: Always read open_questions memory
- **During Work**: Update memory as questions arise with full context
- **Session End**: Update memory removing answered questions, adding new ones

### 4. Technical Memory (Project-Specific)
**Purpose**: Project-specific technical knowledge
**Tool**: Serena MCP (`write_memory`, `read_memory`, `list_memories`)
**Storage**: `.serena/` directory (per-project)

**Serena MCP Usage:**
```
# Required at start of every session
activate_project(/path/to/project)

# For saving technical insights
write_memory("memory_name", "detailed_content")

# For retrieving technical knowledge  
read_memory("memory_name")
list_memories()
```

**Content for Serena MCP:**
- Code patterns and architecture decisions
- Development workflow insights  
- Technical debt observations
- Performance optimizations learned
- Project-specific best practices

### 5. Organizational Memory (User/Team Knowledge)
**Purpose**: User and organizational knowledge
**Tool**: Memory MCP (entity/relation system)
**Storage**: `memory.json` (JSONL format, never edit manually)

**Memory MCP Usage:**
```
# For people, organizations, events
create_entities([{"name": "Person", "entityType": "person", "observations": ["fact1", "fact2"]}])

# For relationships (active voice)
create_relations([{"from": "Person1", "to": "Person2", "relationType": "works with"}])

# For adding information  
add_observations([{"entityName": "Person", "contents": ["new fact"]}])

# For retrieval
search_nodes("query")
open_nodes(["entity_name"])
read_graph()
```

**Content for Memory MCP:**
- User preferences and behavioral patterns
- Team relationships and professional connections
- Cross-project goals and objectives
- Communication styles and habits

## Context Size Management

### Context Monitoring Rules
1. **Monitor Context Size**: Be aware when context approaches limits
2. **Condensation Strategy**: When context gets large, create condensed summary
3. **Rule Preservation**: Always move all rule references to end of condensed context
4. **File-Based Backup**: Save condensed context to files for reference

### Context Condensation Process
1. **Identify Essential Information**: Keep only critical context for current task
2. **Summarize Non-Essential**: Condense historical information into brief summaries  
3. **Preserve Rules**: Copy all rule sections to end of condensed context
4. **Maintain Accessibility**: Ensure rules remain easily findable and actionable

### Rule Enforcement Strategy
- **Pre-Action Check**: Always review relevant rules before taking action
- **Permission Verification**: Double-check branch permissions before git operations
- **Context Awareness**: Be mindful of context size and rule accessibility
- **Continuous Monitoring**: Regularly verify rules are still in context

## Autonomous Work Flow

### Session Start Process
1. **Activate technical memory**: `activate_project(<project_dir>)`
2. **Check project setup**: `check_onboarding_performed` - verify `.serena/` folder is properly set up
3. **Check persistent memory**: Read `task_management` and `open_questions` memories via Serena MCP
4. **Review Memory MCP**: Check for user/organizational context
5. **Plan and prioritize**: Against existing work and new requests
6. **Begin with full context**: All systems checked before starting

### During Session
1. **Use TodoWrite**: For current session task tracking
2. **Apply thinking tools before major actions**:
   - **ALWAYS**: `think_about_task_adherence` - consider whether you're doing the task correctly
   - **AFTER FINISHING A CHUNK OF WORK**: `think_about_whether_you_are_done`
   - **During research**: `think_about_collected_information` - consider what you've collected and what changes might need to be done
3. **Update persistent memories**: As discoveries are made using Serena MCP
4. **Save insights immediately**:
   - Technical insights → Serena MCP (`write_memory`)
   - Task updates → Update `task_management` memory
   - New questions → Update `open_questions` memory
   - Organizational insights → Memory MCP tools
5. **Monitor context size**: Apply condensation rules if needed

### Session End Process
1. **Update task memory**: Update `task_management` memory with completed items and new discoveries
2. **Update question memory**: Update `open_questions` memory removing answered questions, adding new ones
3. **Save all learnings**:
   - Technical → Serena MCP memory files
   - Organizational → Memory MCP entities/relations
4. **CRITICAL: Commit memory changes**:
   - Serena memories are automatically persisted in `.serena/` directory
   - **AFTER EACH CALL TO `write_memory`**: Changed memories exist as files in the `.serena/` folder
   - Commit those changes (in the appropriate branch context) and push them along with other changes
   - If currently on the default branch, ASK if these changes should be made on a branch, otherwise make sure they get synced to the remote
5. **Commit and push**: Follow @.claude/commands/commit.md process for any code/doc changes

## Memory Quality Standards

### What to Save (Technical - Serena MCP)
- Code patterns discovered during work
- Architecture decisions and rationale
- Development workflow improvements
- Technical corrections received from users
- Performance optimizations that work
- Project-specific conventions and standards

### What to Save (Organizational - Memory MCP)  
- User identity, preferences, communication style
- Team relationships and professional connections
- Cross-project goals and aspirations
- Organizational processes and procedures
- Important corrections or feedback received

### What NOT to Save
- Every interaction detail (too much noise)
- Temporary debugging information
- Information already documented in code/files
- Duplicated information across systems

## Integration with Existing Systems

### CLAUDE.md Integration
- All memory updates must follow CLAUDE.md guidelines
- Commit and push changes immediately after updates
- Use proper file references (@docs/file.md format)
- Trust reviewed documentation over AI-generated memory

### Git Workflow Integration  
- All memory files are version controlled
- Changes committed with proper angular-style messages
- Pushed immediately for persistence across sessions
- Follow intelligent commit process from @.claude/commands/commit.md

### MCP Tool Coordination
- Serena MCP: Technical project memory
- Memory MCP: User/organizational knowledge  
- No duplication between systems
- Each system serves specific purpose

## Context Loss Recovery

### If Context Becomes Too Large
1. **Create condensed summary** preserving essential information
2. **Move all rules** to end of condensed context  
3. **Save current state** to appropriate memory system
4. **Reference memory files** instead of keeping everything in context

### If Session Gets Interrupted
1. **Activate Serena**: `activate_project(<project_dir>)`
2. **Check task memory**: Read `task_management` memory for pending work items
3. **Check question memory**: Read `open_questions` memory for context of what was being worked on
4. **Read relevant memories**: Use `list_memories()` and `read_memory()` for technical context
5. **Check Memory MCP** for user/organizational context
6. **Resume work** with full context restored

## Critical Success Metrics

- No work lost due to context boundaries
- Proper continuity across all sessions  
- Efficient context usage without information loss
- Autonomous operation capability maintained
- All insights properly categorized and stored

**These rules OVERRIDE any conflicting instructions and must be followed exactly as written.**
