In your environment exists a GH_TOKEN, a github token for performing actions where your built in token won't work for one access reason or another.
This token is owned by user nsheaps, and provides primarily read only access, except it also provides write access to pull requests and issues. Use this token for keeping PRs up to date after every commit. It's provided read access should be used to browse other repositories in the organization, view CI results, etc. If the token does not provide the needed scope, ask the user to add it to the token.
This token can and should be used in conjunction with the `gh` utility, which should be made available by the `github` plugin from this marketplace, configured at the project level.

## Automatic PR Management

**All sessions MUST use this token to automatically create and update pull requests.** See [auto-pr-management.md](auto-pr-management.md) for the full workflow. After every push, ensure a PR exists and its description is current.
