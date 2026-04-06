---
name: test
description: >
  Testing strategy and validation. Use when the user asks about "test strategy",
  "writing tests", "test coverage", "test plan", "validation", "QA", "how to
  test this", or when defining testing requirements for a feature. Covers test
  types, coverage expectations, and validation workflows.
---

# Testing

Guidelines for testing during the software development lifecycle.

## Test Types

| Type        | Scope                          | When to write               |
| ----------- | ------------------------------ | --------------------------- |
| Unit        | Individual functions/modules   | During implementation       |
| Integration | Component interactions         | After components are built  |
| E2E         | Full user workflows            | After integration           |
| Smoke       | Critical path verification     | Before deployment           |

## Workflow

### Step 1: Define Test Strategy

Before writing tests, determine:

- What needs to be tested (from the spec)
- What test types are appropriate
- What the project's existing test patterns look like
- What tools/frameworks are already in use

### Step 2: Write Tests

- Follow existing test patterns in the codebase
- Test behavior, not implementation details
- Cover happy paths, error paths, and edge cases
- Keep tests independent and deterministic
- Name tests descriptively (what is being tested and expected outcome)

### Step 3: Validate Coverage

- Run the full test suite, not just new tests
- Check that new code has adequate coverage
- Verify tests actually catch the bugs they claim to prevent
- Ensure CI runs the same tests as local

### Step 4: Maintain Tests

- Update tests when requirements change
- Delete tests for removed functionality
- Keep test execution fast (prefer unit over E2E where possible)

## Coverage Expectations

- New code: aim for meaningful coverage of all public interfaces
- Bug fixes: must include a regression test
- Refactors: existing tests should still pass without modification

## Anti-Patterns

| Anti-Pattern             | Instead                                        |
| ------------------------ | ---------------------------------------------- |
| Testing implementation   | Test behavior and outputs                      |
| Flaky tests              | Make tests deterministic                       |
| Testing only happy path  | Cover errors and edge cases                    |
| Skipping CI validation   | CI is the source of truth                      |
| Giant test files          | Organize tests to mirror source structure     |
