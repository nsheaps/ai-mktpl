# Agent Selection Guide

## Quick Decision Tree

### Documentation Needs → `docs-specialist`
- API documentation, user guides, README files
- Technical specifications, troubleshooting guides
- Developer-focused content with practical examples

### System Design → `system-architect` 
- Architecture planning and scalability analysis
- Error handling patterns and failure coordination
- Component boundaries and technology selection

### Feature Implementation → `engineer`
- Translating specs (PRDs, ADRs) into production code
- Code quality improvement and simplification
- Following specifications while maintaining clean code

### Legacy Code Work → `modernization-specialist`
- Refactoring and technical debt reduction
- Legacy system modernization
- Incremental improvements with safety guarantees

### Developer Tools → `dev-tools`
- CLI development and build optimization
- Developer experience improvements
- Workflow automation and productivity tooling

### AI Platform Work → `ai-developer`
- Claude configuration and MCP server development
- Agent creation and AI tool development  
- Cross-platform AI development (Claude Code, Cursor, etc.)

## Remaining Specialized Agents (in .claude/agents/)

- **project-manager**: Project coordination and planning
- **researcher**: Information gathering and analysis
- **tattletale-reporter**: Code quality reporting and issue detection
- **dependency-manager**: Package and dependency management
- **build-engineer**: Pure build system optimization (distinct from dev-tools)
- **multi-agent-coordinator**: Agent orchestration
- **knowledge-synthesizer**: Information synthesis and summarization
- **performance-monitor**: Performance analysis and monitoring

## Consolidation Summary

**Before**: 24 agents with significant overlap and decision confusion
**After**: 15 total agents (6 new consolidated + 9 specialized unchanged)

**Benefits**:
- Clearer agent selection with distinct boundaries
- Reduced context overhead (shorter, focused agents)
- Eliminated duplicate functionality
- Better cross-platform compatibility (ai-developer supports multiple AI platforms)

## Agent Location

- **New consolidated agents**: `.ai/agents/` (6 agents)
- **Legacy specialized agents**: `.claude/agents/` (9 agents)