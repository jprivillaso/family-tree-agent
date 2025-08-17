#!/bin/bash

# Neo4j Database Seeding Script
# This script will run the neo4j_init.cypher file to populate the database

set -e

echo "🌱 Seeding Neo4j Database with Family Tree Data"
echo "=============================================="

# Check if Docker Compose is running
if ! docker-compose ps neo4j | grep -q "Up"; then
    echo "❌ Neo4j container is not running. Starting it now..."
    docker-compose up -d neo4j
    echo "⏳ Waiting for Neo4j to be ready..."
    sleep 15
fi

# Check if Neo4j is accessible
echo "🔍 Checking Neo4j connection..."
for i in {1..30}; do
    if docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 "RETURN 1" &> /dev/null; then
        echo "✅ Neo4j is ready!"
        break
    fi
    echo "   Waiting for Neo4j... (attempt $i/30)"
    sleep 2
done

# Clear existing data (optional - uncomment if you want to start fresh)
echo "🗑️  Clearing existing data..."
docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 "MATCH (n) DETACH DELETE n"

# Run the initialization script
echo "📝 Running neo4j_init.cypher..."
if docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 < scripts/neo4j_init.cypher; then
    echo "✅ Database seeded successfully!"
else
    echo "❌ Failed to seed database. Check the cypher script for errors."
    exit 1
fi

# Show summary
echo ""
echo "📊 Database Summary:"
docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 "MATCH (p:Person) RETURN count(p) as total_people"
docker-compose exec -T neo4j cypher-shell -u neo4j -p familytree123 "MATCH ()-[r]->() RETURN type(r) as relationship_type, count(r) as count ORDER BY count DESC"

echo ""
echo "🎉 Seeding completed!"
echo ""
echo "🌐 Access Neo4j Browser at: http://localhost:7474"
echo "🔐 Login credentials:"
echo "   Username: neo4j"
echo "   Password: familytree123"
echo ""
echo "💡 Try these sample queries in the Neo4j Browser:"
echo "   MATCH (p:Person) RETURN p LIMIT 10"
echo "   MATCH (p:Person)-[r]->(q:Person) RETURN p, r, q"
