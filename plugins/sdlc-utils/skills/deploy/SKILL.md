---
name: deploy
description: >
  Deployment and release management. Use when the user asks about "deployment",
  "CI/CD", "release", "shipping", "publishing", "deploy pipeline", "release
  process", or when setting up or managing deployment workflows. Covers CI/CD
  configuration, release strategies, and deployment validation.
---

# Deployment

Guidelines for deploying and releasing software.

## Workflow

### Step 1: Pre-Deployment Checklist

Before deploying:

- [ ] All tests pass in CI
- [ ] Code review approved
- [ ] No known blocking issues
- [ ] Deployment plan documented (if non-trivial)
- [ ] Rollback strategy identified

### Step 2: CI/CD Pipeline

- CI should be easily reproducible locally using the same source of truth
- CI failures are considered validation failures regardless of local results
- Pipelines should be fast — parallelize independent steps
- Keep pipeline configuration DRY (reusable workflows/actions)

### Step 3: Release Strategy

Choose appropriate strategy for the change:

| Strategy      | When to use                          |
| ------------- | ------------------------------------ |
| Rolling       | Low-risk changes, stateless services |
| Blue-green    | Need instant rollback capability     |
| Canary        | High-risk changes, gradual rollout   |
| Feature flags | Decoupling deploy from release       |

### Step 4: Post-Deployment Validation

After deploying:

- Run smoke tests against the deployed environment
- Monitor error rates and key metrics
- Verify the change works as expected in production
- Keep rollback ready for a defined period

## Anti-Patterns

| Anti-Pattern       | Instead                                 |
| ------------------ | --------------------------------------- |
| Manual deployments | Automate with CI/CD                     |
| No rollback plan   | Always have a rollback strategy         |
| Skipping staging   | Validate in a staging environment first |
| Big-bang releases  | Deploy incrementally                    |
| Deploy on Friday   | Deploy when you can monitor the result  |
