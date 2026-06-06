# App as Codeowner

**Status:** Draft -- needs research
**Scope:** Phase 8 / full audit
**Created:** 2026-04-26

## Problem

GitHub Apps cannot be directly assigned as CODEOWNERS or required reviewers. This creates a gap in the workflow where AI agent bots (jack-nsheaps[bot], henry-nsheaps[bot]) author and review PRs but cannot satisfy CODEOWNERS requirements natively.

### Current workaround

- Labels (e.g., `request-review`) and CI triggers are used to invoke the review bot
- The review bot posts reviews as a GitHub App, but these reviews do not satisfy CODEOWNERS rules
- Human approval from @nsheaps is still required for all merges

## Open questions

These questions need research before a design can be finalized:

1. **Service account as trigger source:** Should we use a service account (machine user) as the source for review triggers instead of labels? This would give us a "real" GitHub user that can be assigned as a reviewer and satisfy CODEOWNERS.

2. **App identity for commits/PRs/reviews:** Can we keep the GitHub App as the primary identity for commits, PRs, and reviews (for proper linking and audit trail) while using a service account only for CODEOWNERS satisfaction?

3. **Multiple service accounts:** If we go the service account route, we likely need more than one -- one per agent (jack, henry, etc.) to maintain identity separation and audit trails.

4. **Service account as codeowner + app as reviewer:** There is ambiguity in whether the review should be posted as the service account (to satisfy CODEOWNERS) rather than the app. This would lose the clean app-based identity linking. What are the trade-offs?

5. **Native app-as-codeowner support:** Is there an existing or upcoming GitHub mechanism that allows Apps to be listed in CODEOWNERS directly? Has this been requested as a GitHub feature?

6. **Are we reinventing the wheel?** Should we lean on regular CODEOWNERS with the app in the list (if it works at all) and rely on CI automations to block merging if the review is not done by the agent? This would be simpler but may not provide the same guarantees.

## Possible approaches (to be evaluated)

### A. Service accounts as codeowners

- Create machine user accounts (one per agent)
- List them in CODEOWNERS
- Reviews still posted by the App, but the service account "approves" via API
- Pro: Clean separation, works with GitHub's native CODEOWNERS
- Con: Requires managing service account credentials, extra cost

### B. CI-based merge gating

- Keep CODEOWNERS as-is (human only)
- Add a required status check that verifies the agent's review exists and is approved
- Merge is blocked by CI, not by CODEOWNERS
- Pro: No service accounts needed, simpler
- Con: Bypasses CODEOWNERS semantics, less visible in GitHub UI

### C. App listed in CODEOWNERS (if supported)

- Research whether `app/henry-nsheaps[bot]` or similar syntax works in CODEOWNERS
- Pro: Simplest if it works
- Con: May not be supported at all

## Next steps

- [ ] Research GitHub's current support for apps/bots in CODEOWNERS
- [ ] Evaluate service account costs and management overhead
- [ ] Prototype approach B (CI-based gating) as a low-effort interim solution
- [ ] Decide on long-term approach based on research findings
