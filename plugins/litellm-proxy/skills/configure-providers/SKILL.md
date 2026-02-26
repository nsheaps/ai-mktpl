---
name: configure-providers
description: >
  Add, remove, and manage LLM provider configurations in LiteLLM proxy.
  Covers API key setup, model routing, wildcard providers, load balancing,
  and fallback chains for Anthropic, OpenAI, Google, AWS Bedrock, Azure, and more.
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Configure LLM Providers

This skill helps configure LLM providers in a LiteLLM proxy. It covers obtaining API keys, setting up model routing, configuring load balancing, and managing fallback chains.

## When to Use This Skill

- User wants to add a new LLM provider (OpenAI, Anthropic, Gemini, etc.)
- User wants to configure API keys for providers
- User wants to set up load balancing across providers
- User wants to configure model aliases or fallbacks
- User mentions adding "another model" or "provider"

## Interactive Provider Setup

### Step 1: Ask Which Providers

Prompt the user for which providers they want to configure. Common options:

| Provider         | Prefix          | API Key Env Var                               |
| ---------------- | --------------- | --------------------------------------------- |
| Anthropic        | `anthropic/`    | `ANTHROPIC_API_KEY`                           |
| OpenAI           | `openai/`       | `OPENAI_API_KEY`                              |
| Google Gemini    | `gemini/`       | `GEMINI_API_KEY`                              |
| Google Vertex AI | `vertex_ai/`    | (service account)                             |
| AWS Bedrock      | `bedrock/`      | `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY` |
| Azure OpenAI     | `azure/`        | `AZURE_API_KEY`                               |
| Groq             | `groq/`         | `GROQ_API_KEY`                                |
| DeepSeek         | `deepseek/`     | `DEEPSEEK_API_KEY`                            |
| Ollama           | `ollama/`       | (none, local)                                 |
| Cohere           | `cohere/`       | `COHERE_API_KEY`                              |
| Mistral          | `mistral/`      | `MISTRAL_API_KEY`                             |
| Together AI      | `together_ai/`  | `TOGETHERAI_API_KEY`                          |
| Fireworks AI     | `fireworks_ai/` | `FIREWORKS_AI_API_KEY`                        |

### Step 2: Obtain API Keys

For each selected provider, guide the user on how to get API keys:

**Anthropic:**

```
1. Go to https://console.anthropic.com/
2. Navigate to API Keys
3. Create a new key
4. Export: export ANTHROPIC_API_KEY="sk-ant-..."
```

**OpenAI:**

```
1. Go to https://platform.openai.com/api-keys
2. Create new secret key
3. Export: export OPENAI_API_KEY="sk-..."
```

**Google Gemini:**

```
1. Go to https://aistudio.google.com/apikey
2. Create API key
3. Export: export GEMINI_API_KEY="AI..."
```

**Google Vertex AI:**

```
1. Install gcloud CLI: https://cloud.google.com/sdk/docs/install
2. Authenticate: gcloud auth application-default login
3. Set project: export GOOGLE_CLOUD_PROJECT="your-project-id"
4. Enable Vertex AI API in your GCP console
```

**AWS Bedrock:**

```
1. Go to AWS Console → IAM → Users → Security Credentials
2. Create access key
3. Export:
   export AWS_ACCESS_KEY_ID="AKIA..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_DEFAULT_REGION="us-east-1"
4. Enable model access in AWS Bedrock console
```

**Azure OpenAI:**

```
1. Go to Azure Portal → Azure OpenAI → your resource
2. Navigate to Keys and Endpoint
3. Export:
   export AZURE_API_KEY="..."
   export AZURE_API_BASE="https://your-resource.openai.azure.com/"
```

**Groq:**

```
1. Go to https://console.groq.com/keys
2. Create API key
3. Export: export GROQ_API_KEY="gsk_..."
```

**DeepSeek:**

```
1. Go to https://platform.deepseek.com/api-keys
2. Create API key
3. Export: export DEEPSEEK_API_KEY="sk-..."
```

**Ollama (local):**

```
1. Install: curl -fsSL https://ollama.com/install.sh | sh
2. Pull a model: ollama pull llama3.1
3. Ollama runs on http://localhost:11434 by default
```

### Step 3: Configure in LiteLLM config.yaml

The config file is typically at `~/.litellm/config.yaml`.

**Wildcard routing (recommended for simplicity):**

```yaml
model_list:
  # Routes any anthropic/* model automatically
  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: "openai/*"
    litellm_params:
      model: "openai/*"
      api_key: os.environ/OPENAI_API_KEY
```

**Explicit model routing (for fine-grained control):**

```yaml
model_list:
  - model_name: claude-sonnet
    litellm_params:
      model: anthropic/claude-sonnet-4-20250514
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: gpt-4o
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY
```

### Step 4: Configure Load Balancing (Optional)

Add multiple deployments with the same `model_name` to enable load balancing:

```yaml
model_list:
  # Primary Anthropic account
  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY

  # Secondary Anthropic account (load balanced)
  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY_2

  # Bedrock fallback for Anthropic models
  - model_name: "anthropic/*"
    litellm_params:
      model: "bedrock/anthropic.*"
      aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID
      aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY
      aws_region_name: "us-east-1"

router_settings:
  routing_strategy: "least-busy" # Options: simple-shuffle, least-busy, usage-based-routing, latency-based-routing
  num_retries: 3
  timeout: 120
  retry_after: 5
  allowed_fails: 3
  cooldown_time: 60
```

### Step 5: Configure Fallbacks (Optional)

Set up cross-provider fallbacks:

```yaml
router_settings:
  fallbacks:
    - claude-sonnet:
        - gpt-4o
        - gemini-pro
    - gpt-4o:
        - claude-sonnet
```

### Step 6: Configure Model Aliases (Optional)

Map friendly names to specific models:

```yaml
model_list:
  - model_name: "fast"
    litellm_params:
      model: "groq/llama-3.1-70b-versatile"
      api_key: os.environ/GROQ_API_KEY

  - model_name: "smart"
    litellm_params:
      model: "anthropic/claude-sonnet-4-20250514"
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: "cheap"
    litellm_params:
      model: "deepseek/deepseek-chat"
      api_key: os.environ/DEEPSEEK_API_KEY
```

### Step 7: Persist Environment Variables

After configuring API keys, persist them:

```bash
# Add to shell profile (~/.bashrc or ~/.zshrc)
cat >> ~/.bashrc << 'EOF'
# LiteLLM provider API keys
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."
# ... more keys
EOF
source ~/.bashrc
```

For better security, use a secrets manager or `.env` file:

```bash
# Create .env file (add to .gitignore!)
cat > ~/.litellm/.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
LITELLM_MASTER_KEY=sk-litellm-...
EOF

# Load before starting proxy
set -a && source ~/.litellm/.env && set +a
litellm --config ~/.litellm/config.yaml
```

### Step 8: Verify Provider Configuration

```bash
# List configured models via API
curl -s http://localhost:4000/v1/models \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" | jq '.data[].id'

# Test a specific provider
curl -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "anthropic/claude-sonnet-4-20250514",
    "messages": [{"role": "user", "content": "Say hello"}],
    "max_tokens": 10
  }'
```

## Multiple Claude Code Accounts

LiteLLM makes it easy to use multiple Anthropic API keys (e.g., personal + work accounts) with automatic load balancing:

```yaml
model_list:
  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY_PERSONAL

  - model_name: "anthropic/*"
    litellm_params:
      model: "anthropic/*"
      api_key: os.environ/ANTHROPIC_API_KEY_WORK

router_settings:
  routing_strategy: "usage-based-routing"
  num_retries: 2
```

This distributes requests across both accounts automatically.
