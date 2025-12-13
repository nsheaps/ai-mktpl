# Claude Configuration Framework

This directory contains the comprehensive configuration framework for Claude Code, providing structured guidance for advanced task orchestration, multi-agent coordination, and workflow optimization.

## 📁 Directory Structure

```
.claude/
├── core/           # Core framework and principles
├── agents/         # Agent definitions for orchestration
├── commands/       # Command system definitions
├── modes/          # Execution mode configurations
└── docs/           # Workflow and best practices documentation
```

## 🎯 Core Framework

### [core/engineering-principles.md](core/engineering-principles.md)
Software engineering principles and decision framework including:
- Philosophy and engineering mindset (SOLID, DRY, KISS, YAGNI)
- Decision framework with data-driven choices
- Trade-off analysis and risk management
- Quality philosophy and standards

### [core/RULES.md](core/RULES.md)
Behavioral rules with priority system:
- 🔴 **CRITICAL**: Security, data safety, production breaks
- 🟡 **IMPORTANT**: Quality, maintainability, professionalism
- 🟢 **RECOMMENDED**: Optimization, style, best practices
- Conflict resolution hierarchy and quick reference decision trees

### [core/FLAGS.md](core/FLAGS.md)
Execution mode flags and tool selection patterns:
- Mode activation flags (--brainstorm, --introspect, --task-manage)
- MCP server flags for tool selection
- Analysis depth flags (--think, --think-hard, --ultrathink)
- Execution control flags for delegation and concurrency

## 🤖 Meta-Orchestration Agents

### [agents/multi-agent-coordinator.md](agents/multi-agent-coordinator.md)
Expert in complex workflow orchestration, inter-agent communication, and distributed system coordination.

### [agents/agent-organizer.md](agents/agent-organizer.md)
Specializes in multi-agent orchestration, team assembly, and workflow optimization.

### [agents/context-manager.md](agents/context-manager.md)
Masters information storage, retrieval, and synchronization across multi-agent systems.

### [agents/workflow-orchestrator.md](agents/workflow-orchestrator.md)
Expert in complex process design, state machine implementation, and business process automation.

## 🚀 Command System

### [commands/spawn.md](commands/spawn.md)
Meta-system task orchestration with intelligent breakdown and delegation for complex multi-domain operations.

### [commands/workflow.md](commands/workflow.md)
Generate structured implementation workflows from PRDs and feature requirements with multi-persona coordination.

### [commands/index.md](commands/index.md)
Generate comprehensive project documentation and knowledge base with intelligent organization.

## 🎚️ Execution Modes

### [modes/MODE_Orchestration.md](modes/MODE_Orchestration.md)
Intelligent tool selection mindset for optimal task routing and resource efficiency.

### [modes/MODE_Task_Management.md](modes/MODE_Task_Management.md)
Hierarchical task organization with persistent memory for complex multi-step operations.

## 📚 Documentation

### [docs/workflow-best-practices.md](docs/workflow-best-practices.md)
Best practices for:
- Working on existing branches
- Opening and managing PRs
- Completing tasks and addressing feedback
- Branch management and commit patterns

### [docs/context-management.md](docs/context-management.md)
Critical context management rules for:
- Context size monitoring and condensation
- Rule preservation and accessibility
- Enforcement strategies

## 🎮 Quick Start Guide

### Activating Modes
```bash
# For complex multi-step tasks
--task-manage

# For intelligent tool selection
--orchestrate

# For deep analysis
--think-hard
```

### Using Commands
```bash
# Orchestrate complex tasks
/sc:spawn "implement authentication system"

# Generate workflows from PRDs
/sc:workflow feature-spec.md --strategy systematic

# Create documentation
/sc:index . --type docs
```

### Agent Invocation
Agents can be invoked through the Task tool for specialized operations requiring domain expertise.

## 🔄 Tool Selection Matrix

| Task Type | Primary Tool | Mode/Flag |
|-----------|-------------|-----------|
| UI Components | Magic MCP | --magic |
| Deep Analysis | Sequential MCP | --seq |
| Multi-file Edits | MultiEdit | Default |
| Complex Workflows | Task Agent | --delegate |
| Documentation | Context7 MCP | --c7 |

## 📊 Priority Quick Reference

### Critical (Never Compromise)
- Security and data safety
- Git branch protection
- Root cause analysis
- Absolute paths

### Important (Strong Preference)
- Complete implementations
- Build only what's asked (MVP)
- Professional language
- Clean workspace

### Recommended (When Practical)
- Parallel operations
- Descriptive naming
- MCP tools over basic alternatives
- Batch operations

## 🔗 Integration

This framework integrates with:
- Claude Code's native tools
- MCP (Model Context Protocol) servers
- Task management systems
- Version control workflows

## 📝 Notes

- All paths are relative to the `.claude/` directory
- Configurations can be overridden locally
- Modes and flags can be combined for enhanced behavior
- Agents work collaboratively through defined communication protocols

For updates and improvements to this framework, submit changes following the workflow practices defined in [docs/workflow-best-practices.md](docs/workflow-best-practices.md).