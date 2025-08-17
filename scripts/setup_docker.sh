#!/bin/bash

# Family Tree Agent Docker Setup Script

set -e

echo "🚀 Setting up Family Tree Agent with Docker"
echo "=========================================="

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Visit: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "   Visit: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker and Docker Compose are available"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp env.template .env
    echo "✅ Created .env file. Please review and update the values if needed."
else
    echo "✅ .env file already exists"
fi

# Pull and start services
echo "🐳 Starting Docker services..."
docker-compose up -d

echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check Neo4j health
echo "🔍 Checking Neo4j connection..."
for i in {1..30}; do
    if docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 "RETURN 1" &> /dev/null; then
        echo "✅ Neo4j is ready!"
        break
    fi
    echo "   Waiting for Neo4j... (attempt $i/30)"
    sleep 2
done

# Check Ollama health
echo "🔍 Checking Ollama connection..."
for i in {1..30}; do
    if curl -f http://localhost:11434/api/tags &> /dev/null; then
        echo "✅ Ollama is ready!"
        break
    fi
    echo "   Waiting for Ollama... (attempt $i/30)"
    sleep 2
done

echo ""
echo "🎉 Setup completed successfully!"
echo ""
echo "📋 Service Information:"
echo "   Neo4j Browser: http://localhost:7474"
echo "   Neo4j Bolt:    bolt://localhost:7687"
echo "   Ollama API:    http://localhost:11434"
echo ""
echo "🔐 Neo4j Credentials:"
echo "   Username: neo4j"
echo "   Password: familytree123"
echo ""
echo "📚 Next Steps:"
echo "   1. Open Neo4j Browser at http://localhost:7474"
echo "   2. Login with the credentials above"
echo "   3. Pull Ollama models:"
echo "      docker-compose exec ollama ollama pull llama3.2"
echo "      docker-compose exec ollama ollama pull nomic-embed-text"
echo "   4. Start your Elixir application: mix phx.server"
echo ""
echo "🛑 To stop services: docker-compose down"
echo "🗑️  To remove data: docker-compose down -v"
