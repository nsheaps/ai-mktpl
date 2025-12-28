# GitHub App Authentication Action

A composite GitHub Action that authenticates as a GitHub App and configures git user settings automatically.

## Features

- Generates a GitHub App token using the App ID and private key
- Retrieves the GitHub App's bot user ID
- Configures git global settings with the app's bot identity
- Outputs token, app-slug, and user-id for use in subsequent steps

## Usage

### Basic Usage

```yaml
steps:
  - name: Authenticate as GitHub App
    id: auth
    uses: ./.github/actions/github-app-auth
    with:
      app-id: ${{ secrets.AUTOMATION_GITHUB_APP_ID }}
      private-key: ${{ secrets.AUTOMATION_GITHUB_APP_PRIVATE_KEY }}

  - name: Checkout with app token
    uses: actions/checkout@v4
    with:
      token: ${{ steps.auth.outputs.token }}
```

### With Custom Owner

```yaml
steps:
  - name: Authenticate as GitHub App
    id: auth
    uses: ./.github/actions/github-app-auth
    with:
      app-id: ${{ secrets.AUTOMATION_GITHUB_APP_ID }}
      private-key: ${{ secrets.AUTOMATION_GITHUB_APP_PRIVATE_KEY }}
      owner: my-org
```

## Inputs

| Name | Description | Required | Default |
|------|-------------|----------|---------|
| `app-id` | GitHub App ID | Yes | - |
| `private-key` | GitHub App private key | Yes | - |
| `owner` | Repository owner | No | `${{ github.repository_owner }}` |

## Outputs

| Name | Description |
|------|-------------|
| `token` | GitHub App token that can be used for authenticated API calls |
| `app-slug` | GitHub App slug name (e.g., `my-app`) |
| `user-id` | GitHub App bot user ID |

## What It Does

1. **Generates Token**: Uses the `actions/create-github-app-token@v2` action to create a token
2. **Fetches User ID**: Retrieves the bot user ID via the GitHub API
3. **Configures Git**: Sets global git user.name and user.email to the app's bot identity

After this action runs, git is configured to commit as `app-slug[bot]` with the proper email format required by GitHub.

## Example Workflows

### CI Workflow with Auto-commit

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Authenticate as GitHub App
        id: auth
        uses: ./.github/actions/github-app-auth
        with:
          app-id: ${{ secrets.AUTOMATION_GITHUB_APP_ID }}
          private-key: ${{ secrets.AUTOMATION_GITHUB_APP_PRIVATE_KEY }}

      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ steps.auth.outputs.token }}

      - name: Run linter and commit fixes
        run: |
          npm run lint --fix
          git add .
          git commit -m "chore: lint fixes" || true
          git push
```

### CD Workflow with Release

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - name: Authenticate as GitHub App
        id: auth
        uses: ./.github/actions/github-app-auth
        with:
          app-id: ${{ secrets.AUTOMATION_GITHUB_APP_ID }}
          private-key: ${{ secrets.AUTOMATION_GITHUB_APP_PRIVATE_KEY }}

      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ steps.auth.outputs.token }}

      - name: Create release
        run: |
          # Release commands here
          git tag v1.0.0
          git push --tags
```

## Why Use This Action?

This action consolidates the common pattern of:
1. Creating a GitHub App token
2. Getting the bot user ID
3. Configuring git settings

Instead of repeating these steps in every workflow, you can use this single action to handle all three tasks consistently.

## Related

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token) - The underlying action for token generation
- [GitHub Apps Documentation](https://docs.github.com/en/apps) - Learn more about GitHub Apps
