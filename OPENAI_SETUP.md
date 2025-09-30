# OpenAI Client Setup Guide

This guide shows you how to use the new OpenAI client in your Family Tree Agent.

## 🚀 Quick Start

### 1. Set Your API Key
```bash
export OPENAI_API_KEY="your-openai-api-key-here"
```

### 2. Your App is Already Configured!
The app now defaults to OpenAI. No code changes needed.

### 3. Test It Works
```bash
# Run the test script
./scripts/test_ai_clients.exs

# Or start your app normally
mix phx.server
```

## 🔄 Switching Between Clients

### Use OpenAI (Default - Recommended for Production)
```elixir
# In config/dev.exs or config/prod.exs
config :family_tree_agent, ai_client_type: :openai
```

### Use Ollama (For Local Development)
```elixir
# In config/dev.exs
config :family_tree_agent, ai_client_type: :ollama
```

## 💰 Cost Comparison

### Your Family Tree App Usage:
- **Initial embedding**: 9 family members × ~100 tokens = ~900 tokens
- **Monthly queries**: ~100 queries × ~200 tokens = ~20,000 tokens
- **Total monthly**: ~21,000 tokens

### OpenAI Costs:
- **Embeddings**: 21,000 tokens × $0.02/1M = **$0.0004/month**
- **Text generation**: 20,000 tokens × $0.60/1M = **$0.012/month**
- **Total**: **~$0.01/month** (essentially free!)

### Fly.io Deployment Costs:
- **OpenAI**: $0.01/month + normal app hosting
- **Ollama**: $40+/month for GPU instances

**Winner**: OpenAI by a huge margin for cloud deployment!

## 🛠️ Configuration Options

### OpenAI Models (Current Setup)
```elixir
openai: [
  embedding_model: "text-embedding-3-small",  # $0.02/1M tokens
  chat_model: "gpt-4o-mini"                   # $0.15 input, $0.60 output per 1M tokens
]
```

### Alternative OpenAI Models
```elixir
openai: [
  embedding_model: "text-embedding-3-large",  # Better quality, $0.13/1M tokens
  chat_model: "gpt-4o"                        # Best quality, $2.50 input, $10 output per 1M tokens
]
```

## 🔧 Environment-Specific Setup

### Development (Local)
```bash
# Option 1: Use OpenAI (recommended)
export OPENAI_API_KEY="your-key"

# Option 2: Use Ollama (if you have it running)
# Uncomment in config/dev.exs:
# config :family_tree_agent, ai_client_type: :ollama
```

### Production (Fly.io)
```bash
# Set the secret in Fly.io
fly secrets set OPENAI_API_KEY="your-key"

# The app will automatically use OpenAI
```

## 🧪 Testing Your Setup

### Test Script
```bash
./scripts/test_ai_clients.exs
```

### Manual Testing
```elixir
# In iex -S mix
alias FamilyTreeAgent.AI.ClientFactory

# Create client
{:ok, client} = ClientFactory.create_client()

# Test embedding
embedding = client.__struct__.create_embedding(client, "Hello world")
IO.inspect(Nx.shape(embedding))

# Test text generation
{:ok, response} = client.__struct__.generate_text(client, "Who is Juan Pablo?")
IO.puts(response)
```

## 🚨 Troubleshooting

### "OpenAI API key not found"
```bash
# Make sure the environment variable is set
echo $OPENAI_API_KEY

# Or check in Elixir
System.get_env("OPENAI_API_KEY")
```

### "Connection refused" (Ollama)
```bash
# Make sure Ollama is running
ollama serve

# Check if models are available
ollama list
```

### "Module not found" errors
```bash
# Recompile the app
mix deps.get
mix compile
```

## 📊 Monitoring Usage

### OpenAI Dashboard
- Visit: https://platform.openai.com/usage
- Monitor your token usage and costs
- Set up billing alerts

### App Logs
```bash
# Your app will log which client it's using
mix phx.server
# Look for: "🤖 Initializing OpenAI client..."
```

## 🎯 Next Steps

1. **Set your OpenAI API key** and test locally
2. **Deploy to Fly.io** with the secret set
3. **Monitor usage** for the first month
4. **Consider upgrading models** if you need better quality

Your app is now ready to use either OpenAI or Ollama based on your configuration!

## 🔄 Future: Adding More Clients

The system is designed to be extensible. You can easily add:
- Anthropic Claude
- Google Gemini
- Azure OpenAI
- Custom models

Just implement the `RAGBehavior` and add to `ClientFactory`!
