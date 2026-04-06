---
name: implement
description: >
  Coding standards and implementation patterns. Use when the user asks about
  "coding standards", "implementation patterns", "how to structure code",
  "best practices for writing code", "code organization", or when starting
  implementation of a planned feature. Covers code structure, naming
  conventions, error handling, and following existing codebase patterns.
---

# Implementation

Guidelines for writing code during the implementation phase of the SDLC.

## Core Principle: Follow Existing Patterns

Before writing new code, study how similar functionality is already implemented
in the codebase. Match conventions for error handling, logging, configuration,
and code organization.

## Workflow

### Step 1: Understand the Spec

Before writing code, read the relevant specification (from the `plan` phase).
Confirm you understand:

- What the code should do
- What is explicitly out of scope
- What dependencies or constraints exist

### Step 2: Explore the Codebase

Search for existing patterns that relate to your task:

- Similar features or modules
- Shared libraries and helpers
- Error handling conventions
- Logging patterns
- Configuration patterns

If 3+ existing files follow the same pattern, your new code MUST follow it too.

### Step 3: Implement Incrementally

- Start with the smallest working version
- Commit frequently with clear messages
- Keep functions under 50 lines, files under 1000 lines
- Write code that is easy to read and understand
- Add logging at key decision points (not too verbose for production)

### Step 4: Handle Errors Properly

- Never silently swallow errors
- Provide context in error messages (what failed, what was expected)
- Use structured error handling consistent with the codebase
- Log errors with enough detail to diagnose without reproducing

### Step 5: Self-Review Before PR

Before opening a PR, review your own code:

- Does it match the spec?
- Does it follow existing patterns?
- Are there any unnecessary additions?
- Is the code simpler than it could be? (KISS, YAGNI)
- Are there duplications? (DRY)

## Anti-Patterns

| Anti-Pattern                | Instead                                    |
| --------------------------- | ------------------------------------------ |
| Reimplementing shared utils | Use existing helpers                       |
| Giant functions             | Break into smaller, focused functions      |
| Silent error swallowing     | Handle and log errors properly             |
| Premature optimization      | Write clear code first, optimize if needed |
| Scope creep during coding   | Stick to the spec, file issues for extras  |
