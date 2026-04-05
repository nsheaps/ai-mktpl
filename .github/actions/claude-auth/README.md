# Claude Authentication Action

A reusable GitHub Action for authenticating with the Claude API using various secret management providers.

## Features

- **Multiple Secret Providers**: Support for Doppler, 1Password, and raw secrets (GitHub Secrets, environment variables)
- **Secure by Default**: Automatically masks sensitive values in logs
- **Flexible Configuration**: Customizable environment variable names and output options
- **Easy Integration**: Works seamlessly with subsequent workflow steps
- **Auto-Installation**: Automatically installs required CLI tools (Doppler CLI, 1Password CLI)

## Supported Providers

### 1. Raw Secrets (GitHub Secrets)

The simplest method - pass your API key directly from GitHub Secrets or environment variables.

### 2. Doppler

Fetch secrets from [Doppler](https://doppler.com) using service tokens.

### 3. 1Password

Retrieve secrets from [1Password](https://1password.com) using service accounts.

## Usage

### Using Raw Secrets (Recommended for Simple Cases)

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: raw
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Using Doppler

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: doppler
    doppler-token: ${{ secrets.DOPPLER_TOKEN }}
    doppler-project: my-project
    doppler-config: prd
    doppler-key-name: ANTHROPIC_API_KEY
```

### Using 1Password

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: 1password
    onepassword-service-account-token: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
    onepassword-vault: Engineering
    onepassword-item: Claude API Key
    onepassword-field: credential
```

## Complete Workflow Examples

### Example 1: Simple Authentication with Raw Secrets

```yaml
name: Deploy with Claude

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate with Claude
        uses: ./.github/actions/claude-auth
        with:
          provider: raw
          api-key: ${{ secrets.ANTHROPIC_API_KEY }}

      - name: Use Claude API
        run: |
          # ANTHROPIC_API_KEY is now available as an environment variable
          echo "API key is configured: ${ANTHROPIC_API_KEY:0:10}..."
          # Your Claude API calls here
```

### Example 2: Multi-Environment Doppler Setup

```yaml
name: Test and Deploy

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate with Claude (Development)
        uses: ./.github/actions/claude-auth
        with:
          provider: doppler
          doppler-token: ${{ secrets.DOPPLER_TOKEN }}
          doppler-project: my-app
          doppler-config: dev
          export-env-var: ANTHROPIC_API_KEY

      - name: Run tests with Claude
        run: npm test

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate with Claude (Production)
        uses: ./.github/actions/claude-auth
        with:
          provider: doppler
          doppler-token: ${{ secrets.DOPPLER_TOKEN }}
          doppler-project: my-app
          doppler-config: prd
          export-env-var: ANTHROPIC_API_KEY

      - name: Deploy with Claude
        run: npm run deploy
```

### Example 3: 1Password with Custom Output

```yaml
name: Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: ./.github/actions/claude-auth
        with:
          provider: 1password
          onepassword-service-account-token: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          onepassword-vault: AI-Services
          onepassword-item: Claude API
          onepassword-field: api-key
          export-env-var: CLAUDE_API_KEY
          set-github-output: true
        id: auth

      - name: Run Claude Code Review
        env:
          CLAUDE_API_KEY: ${{ env.CLAUDE_API_KEY }}
        run: |
          # Use the API key for code review
          ./scripts/claude-review.sh
```

### Example 4: Matrix Strategy with Different Providers

```yaml
name: Multi-Provider Test

on:
  workflow_dispatch:

jobs:
  test-providers:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        provider:
          - name: raw
            config:
              provider: raw
              api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          - name: doppler
            config:
              provider: doppler
              doppler-token: ${{ secrets.DOPPLER_TOKEN }}
              doppler-project: test-project
              doppler-config: dev

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate with Claude (${{ matrix.provider.name }})
        uses: ./.github/actions/claude-auth
        with: ${{ matrix.provider.config }}

      - name: Verify authentication
        run: |
          if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "Error: ANTHROPIC_API_KEY not set"
            exit 1
          fi
          echo "✓ Authentication successful with ${{ matrix.provider.name }}"
```

## Inputs

| Input                               | Description                                            | Required    | Default             |
| ----------------------------------- | ------------------------------------------------------ | ----------- | ------------------- |
| `provider`                          | Secret provider to use (`raw`, `doppler`, `1password`) | Yes         | `raw`               |
| `api-key`                           | Claude API key (for `raw` provider)                    | Conditional | -                   |
| `doppler-token`                     | Doppler service token                                  | Conditional | -                   |
| `doppler-project`                   | Doppler project name                                   | No          | -                   |
| `doppler-config`                    | Doppler config name                                    | No          | -                   |
| `doppler-key-name`                  | Name of secret in Doppler                              | No          | `ANTHROPIC_API_KEY` |
| `onepassword-service-account-token` | 1Password service account token                        | Conditional | -                   |
| `onepassword-vault`                 | 1Password vault name/ID                                | No          | -                   |
| `onepassword-item`                  | 1Password item name/ID                                 | No          | `Claude API Key`    |
| `onepassword-field`                 | 1Password field name                                   | No          | `credential`        |
| `export-env-var`                    | Environment variable name to export                    | No          | `ANTHROPIC_API_KEY` |
| `set-github-output`                 | Whether to set GitHub output                           | No          | `true`              |

## Outputs

| Output    | Description                         |
| --------- | ----------------------------------- |
| `api-key` | The Claude API key (masked in logs) |

## Setup Instructions

### Setting up GitHub Secrets (Raw Provider)

1. Go to your repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `ANTHROPIC_API_KEY`
4. Value: Your Claude API key
5. Click "Add secret"

### Setting up Doppler

1. Create a [Doppler account](https://doppler.com)
2. Create a project and config
3. Add your `ANTHROPIC_API_KEY` to Doppler
4. Generate a service token:
   - Go to Project → Access → Service Tokens
   - Click "Generate Service Token"
   - Select the appropriate config
   - Copy the token
5. Add the token to GitHub Secrets as `DOPPLER_TOKEN`

### Setting up 1Password

1. Create a [1Password](https://1password.com) account
2. Set up a service account:
   - Go to Settings → Developer → Service Accounts
   - Click "Create Service Account"
   - Grant access to the vault containing your Claude API key
3. Create an item in 1Password with your API key:
   - Vault: Choose your vault
   - Item: "Claude API Key" (or custom name)
   - Field: Add your API key
4. Add the service account token to GitHub Secrets as `OP_SERVICE_ACCOUNT_TOKEN`

## Environment Variables

After successful authentication, the following environment variable is available in subsequent workflow steps:

- `ANTHROPIC_API_KEY` (or custom name via `export-env-var` input)

You can use it in your workflow like this:

```yaml
- name: Use Claude API
  run: |
    curl https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -H "content-type: application/json" \
      -d '...'
```

## Security Best Practices

1. **Never commit API keys**: Always use secrets management
2. **Use minimal permissions**: Grant only necessary access to service accounts
3. **Rotate tokens regularly**: Update service tokens and API keys periodically
4. **Use environment-specific configs**: Separate dev/staging/prod secrets
5. **Enable secret scanning**: Use GitHub's secret scanning feature
6. **Audit access logs**: Monitor who accesses your secrets

## Troubleshooting

### Error: "api-key input is required"

Make sure you're passing the `api-key` input when using the `raw` provider:

```yaml
with:
  provider: raw
  api-key: ${{ secrets.ANTHROPIC_API_KEY }}
```

### Error: "doppler-token input is required"

Ensure your Doppler token is properly set in GitHub Secrets and passed to the action:

```yaml
with:
  provider: doppler
  doppler-token: ${{ secrets.DOPPLER_TOKEN }}
```

### Error: "Failed to fetch secret from Doppler"

- Verify your Doppler token is valid
- Check that the project and config names are correct
- Ensure the secret name exists in Doppler
- Verify the service token has read access to the secret

### Error: "Failed to fetch secret from 1Password"

- Verify your service account token is valid
- Check that the vault, item, and field names are correct
- Ensure the service account has access to the specified vault
- Verify the item and field exist in 1Password

### Environment variable not available in next step

Make sure the authentication step completes successfully before using the API key:

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: raw
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}

- name: Use Claude API
  run: |
    # This step runs after authentication
    echo "Using API key: ${ANTHROPIC_API_KEY:0:10}..."
```

## Advanced Usage

### Custom Environment Variable Name

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: raw
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    export-env-var: CLAUDE_API_KEY
```

### Using Output in Subsequent Steps

```yaml
- name: Authenticate with Claude
  id: auth
  uses: ./.github/actions/claude-auth
  with:
    provider: raw
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}

- name: Use API Key from Output
  env:
    MY_API_KEY: ${{ steps.auth.outputs.api-key }}
  run: |
    echo "API key loaded from output"
```

### Conditional Provider Selection

```yaml
- name: Authenticate with Claude
  uses: ./.github/actions/claude-auth
  with:
    provider: ${{ vars.SECRET_PROVIDER || 'raw' }}
    api-key: ${{ secrets.ANTHROPIC_API_KEY }}
    doppler-token: ${{ secrets.DOPPLER_TOKEN }}
    doppler-project: ${{ vars.DOPPLER_PROJECT }}
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This action is part of the Claude Code Plugin Marketplace.

## Support

- **Issues**: [GitHub Issues](https://github.com/nsheaps/ai-mktpl/issues)
- **Documentation**: [Claude Code Docs](https://code.claude.com/docs)
- **Discussions**: [GitHub Discussions](https://github.com/nsheaps/ai-mktpl/discussions)

## Related Resources

- [Claude API Documentation](https://docs.anthropic.com/)
- [Doppler Documentation](https://docs.doppler.com/)
- [1Password Developer Documentation](https://developer.1password.com/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
