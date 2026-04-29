# Work Tracking Rules

Cross-cutting rules for how tasks, PRs, milestones, and project management artifacts relate to each other.

> **Applicability:** These rules are platform-agnostic. Concrete implementations (GitHub Issues, Linear, file-based tracking) are provided by separate skills in appropriate plugins. These rules define the abstract relationships and constraints that any implementation must satisfy.

## 1. Linking Requirements

### Every work item MUST link to a milestone

When creating a tracked work item, it must be linked to a milestone or project. If no milestone exists, coordinate with the appropriate role (PM, handler) to create one or assign to an existing one.

### Every PR MUST link to a work item + milestone

When a PR is created, ensure both exist:

1. A tracked work item (issue, ticket, task) for coordination
2. A milestone or project for status rollup

If either is missing, create them or coordinate to have them created.

### PRs MUST be developed against merged specs

- Specs live on default branches in the relevant repos
- Work items are coordination ground ("tickets to assign"), NOT the source of truth for specs
- All specs should be merged (and reviewed if required) before PR work begins

## 2. Status Tracking

### Canonical state lives in the tracking system

The primary record of a work item's status lives in the project management tool (issues, boards, milestones). Communication channels supplement but do not replace the canonical tracking.

### Status updates flow upward

- Work-level updates belong on the work item (PR status, test results, review state)
- Milestone-level updates belong on the milestone (which work items are done, what is left)
- Status communication to stakeholders summarizes from the canonical records

## 3. Moving Tasks Between Milestones

When a task moves milestones:

1. Update the OLD milestone (remove or mark as moved)
2. Update the NEW milestone (add the task)
3. Both updates should be reflected in the canonical tracking system

## Definitions

- **work item** -- A trackable unit of work in the project management system (GitHub Issue, Linear ticket, checklist item, etc.). Has a title, status, and links to related artifacts.
- **milestone** -- A collection of work items representing a project phase, sprint, or release goal. Provides rollup status visibility.
- **handler** -- The human operator who manages and directs the AI agent. The handler provides direction, approves merges, and makes final decisions.
