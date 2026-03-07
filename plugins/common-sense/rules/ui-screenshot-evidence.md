# UI Screenshot Evidence Rule

All UI changes MUST be accompanied by photographic evidence (screenshots).

## Requirements

1. **Screenshot capture**: After making any UI change, capture screenshots demonstrating the change using the E2E screenshot tooling (`bun run test:e2e:screenshots`).
2. **PR inclusion**: Screenshots MUST be included in the pull request body so reviewers can visually verify the change.
3. **Documentation automation**: Screenshots MUST be inserted into documentation pages via automation (not manually). This ensures pictures do not become stale or out of date as the UI evolves.
4. **QA validation**: These automated screenshots also serve as QA validation artifacts. They may be used to verify visual correctness in CI and review workflows.
5. **No manual screenshot management**: Never manually place or update screenshots in documentation. Always rely on the automated pipeline so that docs stay in sync with the actual UI.
