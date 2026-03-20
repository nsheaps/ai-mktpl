# Playwright Visual Regression Testing — Best Practices 2025-2026

**Sources**:
- https://blog.scottlogic.com/2025/08/21/making-visual-comparison-test-maintenance-easier-with-github-actions.html
- https://www.duncanmackenzie.net/blog/visual-regression-testing/
- https://oneuptime.com/blog/post/2026-01-27-playwright-visual-testing/view
- https://testdino.com/blog/playwright-visual-testing/
**Date read**: 2026-03-20

## Key Best Practices

1. **Generate baselines in CI, not locally** — OS differences cause mismatches (macOS vs Linux font rendering)
2. **Use Playwright's Docker image** (`mcr.microsoft.com/playwright`) for consistent rendering
3. **Mask dynamic content** — timestamps, avatars, counters, ads
4. **Disable animations** — `animations: 'disabled'` in screenshot options
5. **Set per-component thresholds** — hero images need tighter tolerance than data tables
6. **Store baselines in git** — they're test artifacts, review them in PRs
7. **Prefer component-level over full-page screenshots** — smaller files, precise failures
8. **Separate visual tests from functional tests** — tag with `@visual`, run on PRs not every commit
9. **Upload reports as artifacts** on failure for easy inspection
10. **Start with Chromium only** — add cross-browser when bugs actually appear

## Key Gotchas

- OS-specific baselines: screenshots are OS and browser specific
- Binary merge conflicts: multiple engineers updating baselines creates git conflicts on PNGs
- At scale, consider cloud-based visual testing (Chromatic, Percy, Applitools)

## Relevance to rest-owl Plugin

Critical updates for our validation-pipeline skill:

1. **Docker container in CI** — Our CI template should use `mcr.microsoft.com/playwright` container image for consistency. Currently missing from our template.
2. **Mask dynamic content** — Should mention this in the E2E test patterns. Timestamps and user-generated IDs will flake without masking.
3. **Baselines in CI, not local** — Our current flow generates baselines locally from mockups. This is fine for initial generation, but CI should regenerate from the actual app in the Docker container.
4. **Separate visual from functional** — Our template already separates these (`e2e/visual/` vs `e2e/flows/`), which aligns with best practices.
5. **Component vs full-page** — Consider recommending component-level screenshots for reusable UI elements.

## Design Implication

Update the CI template to use the Playwright Docker image as a container, add dynamic content masking guidance, and note the OS-baseline gotcha explicitly.
