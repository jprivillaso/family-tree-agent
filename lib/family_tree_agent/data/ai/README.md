# AI Client System

This directory contains the AI client system for the Family Tree Agent, supporting multiple AI providers through a unified interface.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   RAG Systems   │───▶│  ClientFactory   │───▶│   AI Clients    │
│                 │    │                  │    │  (OpenAI/Ollama)│
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Supported Clients

### OpenAI Client (`clients/openai.ex`)
- **Models**: `text-embedding-3-small`, `gpt-4o-mini`
- **Cost**: ~$1-5/month for typical usage
- **Pros**: Fast, reliable, no infrastructure needed
- **Cons**: Requires API key, external dependency

### Ollama Client (`clients/ollama.ex`)
- **Models**: `nomic-embed-text`, `gemma3n:latest`
- **Cost**: Free (requires local hardware)
- **Pros**: Local execution, privacy, no API costs
- **Cons**: Requires powerful hardware, slower

## Configuration

### Environment Variables
```bash
# Required for OpenAI
export OPENAI_API_KEY="your-api-key-here"
```

### Application Configuration

In `config/config.exs`:
```elixir
config :family_tree_agent,
  # Choose your default client
  ai_client_type: :openai,  # or :ollama

  # Client-specific settings
  ai_clients: [
    openai: [
      embedding_model: "text-embedding-3-small",
      chat_model: "gpt-4o-mini"
    ],
    ollama: [
      base_url: "http://localhost:11434",
      embedding_model: "nomic-embed-text",
      chat_model: "gemma3n:latest"
    ]
  ]
```

### Environment Overrides

**Development** (`config/dev.exs`):
```elixir
# Uncomment to use Ollama locally
# config :family_tree_agent, ai_client_type: :ollama
```

**Production**: Uses OpenAI by default (recommended for Fly.io deployment)

## Usage

### Using the Factory (Recommended)
```elixir
# Use configured default client
{:ok, client} = ClientFactory.create_client()

# Override client type
{:ok, client} = ClientFactory.create_client(:openai)

# Custom configuration
{:ok, client} = ClientFactory.create_client(:openai, api_key: "custom-key")
```

### Direct Client Usage
```elixir
# OpenAI
{:ok, client} = OpenAI.init(api_key: "your-key")
embedding = OpenAI.create_embedding(client, "Hello world")
{:ok, response} = OpenAI.generate_text(client, "What is AI?")

# Ollama
{:ok, client} = Ollama.init(base_url: "http://localhost:11434")
embedding = Ollama.create_embedding(client, "Hello world")
{:ok, response} = Ollama.generate_text(client, "What is AI?")
```

## Switching Clients

### For Development
1. **Local Ollama**: Uncomment the line in `config/dev.exs`
2. **OpenAI**: Set `OPENAI_API_KEY` environment variable

### For Production
1. **Fly.io**: Use OpenAI (recommended)
2. **Self-hosted**: Can use either, but Ollama requires GPU instances

## Cost Comparison

| Scenario | OpenAI Cost | Ollama Cost | Recommendation |
|----------|-------------|-------------|----------------|
| Local Dev | $0-1/month | Free | Either |
| Fly.io Deploy | $1-5/month | $40+/month | OpenAI |
| High Volume | $10+/month | Free* | Depends |

*Ollama is free but requires expensive hardware

## Adding New Clients

1. Create a new client module implementing `RAGBehavior`
2. Add it to `ClientFactory.create_client/2`
3. Add configuration in `config/config.exs`
4. Update this README

## Troubleshooting

### OpenAI Issues
- **401 Unauthorized**: Check `OPENAI_API_KEY` environment variable
- **429 Rate Limited**: Reduce request frequency or upgrade plan
- **Connection errors**: Check internet connectivity

### Ollama Issues
- **Connection refused**: Ensure Ollama is running on `localhost:11434`
- **Model not found**: Run `ollama pull model-name` first
- **Out of memory**: Reduce model size or increase RAM

### General Issues
- **Wrong client type**: Check `ai_client_type` in configuration
- **Missing dependencies**: Run `mix deps.get`
- **Compilation errors**: Run `mix compile`
