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
