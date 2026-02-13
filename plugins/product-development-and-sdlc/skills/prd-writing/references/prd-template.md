# PRD Template

Copy this template as the starting point for a new PRD. Fill in sections
iteratively -- do not attempt to complete everything in one pass.

---

# [Feature/Product Name]

**Status:** Draft | In Review | Approved | In Progress | Live | Deprecated
**Author:** [Name]
**Created:** [Date]
**Last Updated:** [Date]
**Reviewers:** [Names]

## 1. Problem Statement

_What problem exists? Who has it? Why does it matter now?_

[Start with 1-2 sentences. Expand in later iterations.]

## 2. Target Users

_Who are the primary and secondary users?_

### Primary Persona

- **Who:** [Role/description]
- **Context:** [When/where they encounter the problem]
- **Current workaround:** [How they solve it today]
- **Pain level:** [Low / Medium / High / Blocking]

### Secondary Persona(s)

[Add as identified through research]

## 3. Goals and Success Metrics

_How do we know this succeeded?_

| Metric        | Current Baseline | Target | How Measured         |
| ------------- | ---------------- | ------ | -------------------- |
| [Metric name] | [Current value]  | [Goal] | [Measurement method] |

### Non-Goals

_What is explicitly out of scope?_

- [Non-goal 1]
- [Non-goal 2]

## 4. Scope

### In Scope

- [Feature/capability 1]
- [Feature/capability 2]

### Out of Scope

- [Explicitly excluded item 1]
- [Explicitly excluded item 2]

### Future Considerations

_Things intentionally deferred but worth noting for future work._

- [Future item 1]

## 5. Requirements

### Functional Requirements

_What the system must do. Add iteratively -- start with high-level, refine
to specific requirements with acceptance criteria._

#### [Requirement Group 1]

| ID     | Requirement   | Priority    | Acceptance Criteria  |
| ------ | ------------- | ----------- | -------------------- |
| FR-001 | [Description] | Must-have   | [Testable criterion] |
| FR-002 | [Description] | Should-have | [Testable criterion] |

#### [Requirement Group 2]

[Add as requirements become clear]

### Non-Functional Requirements

| ID      | Requirement   | Target            |
| ------- | ------------- | ----------------- |
| NFR-001 | Performance   | [Specific target] |
| NFR-002 | Accessibility | [Standard/level]  |
| NFR-003 | Security      | [Requirements]    |

## 6. User Stories

_Decompose requirements into implementable stories. Add after the PRD has
sufficient fidelity (Phase 5 of the iterative process)._

### Epic: [Group Name]

#### Story 1: [Title]

**As a** [persona], **I want to** [action] **so that** [benefit].

**Acceptance Criteria:**

- Given [context], when [action], then [result]
- Given [context], when [action], then [result]

**Priority:** Must-have | Should-have | Nice-to-have
**Estimated Effort:** S | M | L | XL

[Repeat for each story]

## 7. User Flows

_Describe key user journeys. Add diagrams or step-by-step flows._

### Flow 1: [Name]

1. User [action]
2. System [response]
3. User [action]
4. ...

## 8. Technical Considerations

_Add after solution direction is established. Include constraints,
dependencies, and architectural notes._

### Dependencies

- [Dependency 1]
- [Dependency 2]

### Constraints

- [Technical constraint 1]
- [Platform constraint 1]

### Architecture Notes

[High-level technical approach, if known]

## 9. Open Questions

_Track unresolved questions. Remove or move to resolved as they are answered._

| #   | Question   | Owner  | Status   | Resolution |
| --- | ---------- | ------ | -------- | ---------- |
| 1   | [Question] | [Name] | Open     |            |
| 2   | [Question] | [Name] | Resolved | [Answer]   |

## 10. Next Steps

_What happens after this PRD is reviewed/approved?_

1. [ ] [Next step with owner]
2. [ ] [Next step with owner]
3. [ ] [Next step with owner]

## 11. References

_Links to related documents, research, prior art, and external sources._

- [Reference 1](URL)
- [Reference 2](URL)

## Revision History

| Date   | Author | Changes       |
| ------ | ------ | ------------- |
| [Date] | [Name] | Initial draft |
