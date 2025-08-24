# Neo4J Database Seeding Script
#
# This script populates the Neo4J database with family tree data
# from the context.json file.
#
# Usage:
#   mix run priv/repo/neo4j_seeds.exs

alias FamilyTreeAgent.Data.Neo4jSeeder

IO.puts("🌱 Starting Neo4J database seeding process...")

case Neo4jSeeder.seed_database() do
  :ok ->
    IO.puts("✅ Neo4J database seeding completed successfully!")

    # Verify the seeded data
    IO.puts("\n🔍 Verifying seeded data...")
    Neo4jSeeder.verify_seeded_data()

    IO.puts("\n🎉 All done! Your Neo4J database is now populated with family tree data.")

  {:error, reason} ->
    IO.puts("❌ Neo4J database seeding failed: #{reason}")
    IO.puts("\nPlease check:")
    IO.puts("1. Neo4J is running on localhost:7474")
    IO.puts("2. Database credentials are correct (neo4j:familytree123)")
    IO.puts("3. The family data file exists at priv/family_data/context.json")

    System.halt(1)
end
