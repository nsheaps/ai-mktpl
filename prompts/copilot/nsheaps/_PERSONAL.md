<!-- this is in github.com/copilot/agents > settings > Peronal Instructions -->

You're expected to:
- Always start with a private license unless specified (even if public)
- Always set up and update copilot instructions based on things you've learned or been told during sessions.
  - Always set it up on new repos.
- Organize, re-organize to match pattern, maintain, and create documentation, specs, and PRDs in the docs/, docs/specs/, docs/research/ folders
- Utilize CI to validate your code, and wait for results if not already present (unless pending approval)
- New repos should always have:
  - Full, working CI (use view pull request/list actions/get action tools) for:
    - ci / build
    - ci / check    <== linting and formatting, perhaps autofixing
    - ci / test
    If applicable also:
    - cd / release
    - cd / deploy
  - Use mise for tool management, and scripts (into the mise script folder structure) for repo wide tasks
  - Use direnv's .envrc to source every script in the rc.d folder, including:
    - mise setup and auto install of tools
    - adding bin/ to path
    - performing a dry run of (to provide notice to user):
      - a yarn install via nx, utilizing caching inputs on package.json's, yarn.lock and yarn config files
      - extendable with example for additional "run a,b,c when file(s) x(,y,z) change"
  - If a mono-repo (most are in some way), use nx for tasks cross repo. If making a typescript project, prefer utilizing yarn and yarn workspaces and nx's auto detection
    - Must have scripts for check/test/build, which are the same scripts used in the CI workflows
    - encapsulate projects in other languages with a js module wrapper

Generally prefer (unless otherwise guided or unable):
- CI should trigger on "push to main" or "any pull request" (no branch targeting). Doing it on both with the same branch targeting will run the same CI twice
- Typescript(via bun) > Typescript(via node, prefer utilizing methods that don't require compilation) > Go > Python
  - Except where the primary use case of the project utilizes libraries and tools that primarily exist in a particular language, such as:
    - brew uses ruby
    - kubernetes uses go
    - I'm sure some things use python
- Using prettier to format md, js, jsx, json, ts, tsx, html
- Workflows should attempt to fix any errors , push any changes, then fail (if errors are found, otherwise success), rather than fail without being helpful. Configurable from repo/org variable (not secret)
