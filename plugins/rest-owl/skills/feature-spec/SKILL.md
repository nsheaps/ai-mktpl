---
name: feature-spec
description: >
  Comprehensive feature specification from competitive research. Produces detailed
  feature definitions with user stories, acceptance criteria, data models, API specs,
  and edge cases. Used as Phase 2 of the rest-owl workflow.
allowed-tools: Bash, Read, Write, Grep, Glob, Agent, WebSearch, WebFetch, TodoWrite, AskUserQuestion
---

# Feature Specification

Transforms competitive research and user requirements into a detailed, testable feature specification that serves as the contract for implementation.

## When This Skill Activates

- As Phase 2 of the rest-owl workflow
- When a user needs a complete feature spec for a software project
- When converting a feature list into actionable specifications

## Input

- Project brief (`docs/rest-owl/00-intake.md`)
- Competitive research (`docs/rest-owl/01-competitive-research.md`), particularly:
  - Feature priority map (P0-P3)
  - UX patterns
  - Technology recommendations

## Specification Process

### Step 1: Feature Inventory

Extract all features from the competitive research and organize by domain:

```markdown
## Authentication & Authorization

- Sign up (email, OAuth)
- Sign in / Sign out
- Password reset
- Role-based access control
- Session management

## Core Feature Domain

- [Feature 1]
- [Feature 2]
  ...
```

**Group features into logical domains** — these become the module boundaries in the architecture.

### Step 2: Scope Definition

Present the complete feature inventory to the user and confirm scope:

- Which priority levels to include (P0 only? P0+P1? All?)
- Any features to explicitly exclude
- Any features to add that weren't in the research
- MVP cutoff line — draw a clear boundary

Save the scoping decision to the spec document.

### Step 3: Detailed Feature Specification

For **each** feature in scope, write a complete specification:

#### Feature Template

```markdown
### F-[DOMAIN]-[NUMBER]: [Feature Name]

**Priority**: P0 | P1 | P2 | P3
**Domain**: [Which module/domain this belongs to]
**Dependencies**: [Other features this depends on]

#### Description

[2-3 sentence description of what this feature does and why it exists]

#### User Stories

**US-1**: As a [role], I want to [action] so that [benefit].

- **Given** [precondition]
- **When** [action]
- **Then** [expected result]

**US-2**: As a [role], I want to [action] so that [benefit].

- **Given** [precondition]
- **When** [action]
- **Then** [expected result]

#### Acceptance Criteria

- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] [Specific, testable criterion 3]

#### UI Requirements

- [Screen/component where this feature appears]
- [Key interactions and behaviors]
- [Loading states, empty states, error states]

#### Data Requirements

- [What data this feature reads]
- [What data this feature writes]
- [Validation rules]

#### Edge Cases

- [Edge case 1 and expected behavior]
- [Edge case 2 and expected behavior]

#### Error Scenarios

- [Error scenario 1 and how to handle it]
- [Error scenario 2 and how to handle it]
```

### Step 4: Data Model Definition

Define the complete data model for the project:

```markdown
## Data Model

### Entity: [EntityName]

| Field     | Type     | Required | Default | Constraints  |
| --------- | -------- | -------- | ------- | ------------ |
| id        | UUID     | Yes      | auto    | Primary key  |
| name      | string   | Yes      | -       | 1-255 chars  |
| createdAt | datetime | Yes      | now()   | Immutable    |
| updatedAt | datetime | Yes      | now()   | Auto-updated |

**Relationships**:

- Has many [OtherEntity] (one-to-many)
- Belongs to [ParentEntity] (many-to-one)

**Indexes**:

- Unique: [field1, field2]
- Search: [field3] (full-text)
```

### Step 5: API Specification

If the project has an API layer, define endpoints:

````markdown
## API Endpoints

### [Domain] API

#### POST /api/[resource]

- **Description**: Create a new [resource]
- **Auth**: Required (role: user)
- **Request Body**:
  ```json
  {
    "name": "string (required, 1-255 chars)",
    "description": "string (optional, max 5000 chars)"
  }
  ```
````

- **Response 201**:
  ```json
  {
    "id": "uuid",
    "name": "string",
    "createdAt": "ISO 8601"
  }
  ```
- **Error Responses**:
  - 400: Validation error (missing/invalid fields)
  - 401: Not authenticated
  - 403: Insufficient permissions
  - 409: Resource already exists

````

### Step 6: State Management Specification

Document application state requirements:

- **Global state**: Auth, user preferences, app settings
- **Feature state**: Per-domain state that features need
- **UI state**: Modals, sidebars, selections, filters
- **Cache strategy**: What to cache, TTLs, invalidation rules
- **Optimistic updates**: Where to apply optimistic UI patterns

### Step 7: Cross-Cutting Concerns

Document requirements that span multiple features:

- **Authentication flow**: Sign-up, sign-in, token refresh, session expiry
- **Authorization model**: Roles, permissions, resource-level access
- **Error handling strategy**: Global error boundary, toast notifications, retry logic
- **Loading strategy**: Skeleton screens, spinners, progressive loading
- **Offline support**: If applicable, what works offline
- **Accessibility**: WCAG level, keyboard navigation, screen reader support
- **Internationalization**: If applicable, which locales, RTL support
- **Performance budgets**: Page load time, interaction latency, bundle size

## Output Format

Write to `docs/rest-owl/02-feature-spec.md`:

```markdown
# Feature Specification: [Project Name]

## Scope
- **Included priorities**: P0, P1
- **Total features**: [N]
- **Excluded from MVP**: [list]

## Feature Domains
1. [Domain 1] — [N] features
2. [Domain 2] — [N] features
...

## Features

### Domain: [Domain 1]

#### F-AUTH-001: User Registration
[Full feature spec using template above]

#### F-AUTH-002: User Login
[Full feature spec using template above]

...

## Data Model
[Complete entity definitions]

## API Specification
[Complete endpoint definitions]

## State Management
[State requirements]

## Cross-Cutting Concerns
[Shared requirements]

## Glossary
[Domain-specific terms and definitions]
````

## Parallelization

Feature specs within different domains are independent — use `Agent` tool to write specs for multiple domains simultaneously.

## Quality Checks

Before completing this phase:

- [ ] Every P0 and P1 feature has a complete specification
- [ ] Every feature has at least 2 user stories with Given/When/Then
- [ ] Every feature has at least 3 acceptance criteria
- [ ] Every feature identifies edge cases and error scenarios
- [ ] Data model covers all entities referenced by features
- [ ] API endpoints exist for all data operations
- [ ] Cross-cutting concerns are documented
- [ ] No circular dependencies between features
- [ ] User has approved the scope before detailed specs were written
