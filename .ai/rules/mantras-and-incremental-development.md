### Mantras

Don't forget these mantras when working on your projects! What they imply is CRITICAL for maintaining high quality code. Think about them after every task to ensure they're followed.

**KISS** - Keep It Simple, Stupid!
Always aim for simplicity in your designs and implementations.

**YAGNI** - You Aren't Gonna Need It!
Avoid adding features until they are absolutely necessary.

**DRY** - Don't Repeat Yourself!
Eliminate redundancy by reusing code and components.

**WET** - (Don't) Write Everything Twice!
Duplication is the enemy of maintainability; strive for single sources of truth and (re-) organize your project structure as necessary to minimize repetition.

### Defining Specifications

When building something (whether updating, adding, removing, or a brand new project) it is crucial to define clear specifications. Specifications should outline the requirements, constraints, and goals of the task at hand. They serve as a roadmap for development and help ensure that everyone involved has a shared understanding of what needs to be accomplished.

Specifications should be documented in a dedicated file within the project, typically located in docs/specs/....

If the folder does not already exist, it should be created with such a structure as to enable iterative review and state management of specifications over time:

- docs/specs/draft/<spec-name>.md (for initial drafts and brainstorming)
- docs/specs/reviewed/<spec-name>.md (for reviewed and approved specifications, moves to this folder after review)
- docs/specs/in-progress/<spec-name>.md (for specifications currently being implemented)
- docs/specs/live/<spec-name>.md (for finalized specifications that are actively being used in the project)
- docs/specs/deprecated/<spec-name>.md (for outdated or deprecated specifications, but still in use)
- docs/specs/archive/<spec-name>.md (for archived specifications no longer in use)

Specifications are living documents and should be updated as necessary throughout the development process to reflect changes in requirements or understanding. DO NOT OVERCOMPLICATE THEM - keep them concise and focused on the essential and ONLY approved and reviewed details needed to guide development.

**Combined format**: Each spec should contain both *Problem & Requirements* (what and why) and *Technical Design* (how) in a single document. Do not separate these into distinct "PRD" and "spec" documents — use the unified term "spec" for all specification documents.

**Size guidance**: Aim to keep specs under ~500 lines. If a spec grows beyond that, split it into a parent spec (scope/requirements) and child specs (technical details per component).

Specifications may not be useful in all cases, but are required when creating new features for software projects.

### Incremental Development

Adopt an incremental development approach to build your projects step-by-step:

1. **Plan your work**: Break down your project into smaller, manageable tasks.
2. **Outline what you will do**: For each task, outline the steps you will take to complete it.
3. **Define/Update specifications as necessary to accomplish the task**: Clearly define what needs to be done for each task, and update specifications as needed. Specifications should be stored in docs/specs/.... within the project.
4. **Start Small**: Begin with a minimal viable product (MVP) that includes only the core features.
5. **Iterate**: Continuously improve and expand your project in small, manageable increments
6. **Test Frequently**: Regularly test your code to catch issues early and ensure quality.
7. **Refactor**: Periodically revisit and refine your codebase to continue working on your task until the task is complete.

Failure to follow these principles can lead to bloated, unmanageable codebases that are difficult to maintain and evolve over time, and severely overcomplicate implementations that are not yet necessary.

### Incremental Operations: Extract, Migrate, Refactor

The incremental approach applies to operational tasks, not just feature development. When moving, extracting, or restructuring code:

**Move first, improve later.** Separate the act of relocation from the act of modification:

1. **Phase 1 — Pure move**: Copy/move code to its new location with zero functional changes. The code in the new location should behave identically to the original. Verify this with tests or manual validation before proceeding.
2. **Phase 2 — Improvements**: Only after the pure move is verified, make enhancements, refactors, or fixes in the new location.

**Why this matters:**
- Mixing relocation with modification makes it impossible to tell whether breakage comes from the move or the change
- Pure moves are easy to review — "does it still work the same?" is a simple yes/no question
- Improvements on top of a verified move have a known-good baseline to compare against
- If the move fails, you can revert cleanly without losing improvement work (and vice versa)

**This pattern applies to:**
- Extracting code into a new repo or package
- Migrating files between directories or modules
- Splitting monoliths into separate services
- Moving configuration between scopes (project → global, repo → plugin)
- Extracting shared libraries from application code

**Anti-pattern:** "While I'm moving this, I'll also fix/improve/refactor it." This is the single most common cause of botched migrations. Resist the urge.
