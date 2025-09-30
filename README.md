# Family Tree Agent 🌳

An intelligent family tree management system built with Elixir/Phoenix that combines traditional CRUD operations with AI-powered question answering capabilities.

## 🌟 Features

### Core Family Tree Management
- **CRUD Operations**: Create, read, update, and delete family members
- **Rich Data Model**: Store names, birth/death dates, biographies, relationships, and metadata
- **Family Tree Visualization**: Get complete family tree structure with relationships
- **Search Functionality**: Find family members by name

### AI-Powered Intelligence
- **Smart Q&A**: Ask natural language questions about family members
- **Context-Aware Responses**: AI understands family relationships and history
- **RAG System**: Retrieval-Augmented Generation for accurate, contextual answers
- **Resilient Architecture**: GenServer-based AI system with graceful degradation

### Production Ready
- **Health Monitoring**: Built-in health checks for all system components
- **CORS Support**: Ready for frontend integration
- **Database Persistence**: Neo4j GraphRAG database
- **Error Handling**: Comprehensive error responses and logging

## 🚀 Quick Start

### Prerequisites
- Elixir 1.14+
- Phoenix Framework
- Neo4j (for GraphRAG database)
- (Optional) OpenAI API key for enhanced AI responses

### Installation

1. **Clone and setup**
   ```bash
   git clone <your-repo>
   cd family-tree-agent
   mix deps.get
   ```

2. **Database setup**
   ```bash
   mix ecto.setup
   ```

3. **Environment configuration**
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

4. **Start the server**
   ```bash
   mix phx.server
   ```

Visit [`localhost:4000`](http://localhost:4000) - your app is ready! 🎉

## 🏗️ Architecture

### Core Components

- **Phoenix Web Framework**: HTTP API and routing
- **Neo4j GraphRAG**: Advanced graph-based data storage and retrieval
- **GenServer Architecture**: Resilient AI system management
- **RAG System**: AI-powered question answering with context

### AI System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   HTTP Request  │───▶│   RAG Server     │───▶│   AI Model      │
│                 │    │   (GenServer)    │    │   (Bumblebee)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   Family Data    │
                       │   (Neo4j Graph)  │
                       └──────────────────┘
```

### Key Design Decisions

- **Graceful Degradation**: AI system failures don't crash the main application
- **Supervisor Strategy**: `:one_for_one` restart strategy for AI components
- **Error Boundaries**: Comprehensive try/rescue blocks for external AI calls
- **State Management**: GenServer maintains AI model state for performance

## 🛠️ Development

### Code Quality Tools

```bash
# Run all quality checks
mix quality

# Individual checks
mix format              # Code formatting
mix credo --strict     # Static analysis
mix dialyzer           # Type checking
mix test               # Test suite
```

### Neo4j Database

The application uses Neo4j as its primary database. Ensure Neo4j is running locally on `localhost:7474` with credentials `neo4j:familytree123`.

### Adding Family Data

1. **Via API**: Use the POST endpoints to add members programmatically
2. **Via Neo4j**: Add data directly to the Neo4j database using Cypher queries
3. **Via JSON**: Place JSON files in `priv/family_data/` (auto-loaded by RAG system)

## 🚀 Deployment

### Environment Variables

```bash
# AI System (Optional)
OPENAI_API_KEY="your-openai-api-key"

# Neo4j Database (configured in application)
# Neo4j runs on localhost:7474 with credentials neo4j:familytree123
```

### Health Monitoring

Monitor your deployment with the health endpoint:

```bash
curl https://your-app.com/api/health
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run quality checks (`mix quality`)
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Phoenix Framework](https://phoenixframework.org/)
- AI capabilities powered by [Bumblebee](https://github.com/elixir-nx/bumblebee)
- Database management with [Ecto](https://hexdocs.pm/ecto/Ecto.html)
- Code quality tools: [Credo](https://github.com/rrrene/credo) and [Dialyzer](https://erlang.org/doc/man/dialyzer.html)

---

**Happy family tree building!** 🌳✨