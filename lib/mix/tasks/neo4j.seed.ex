defmodule Mix.Tasks.Neo4j.Seed do
  @moduledoc """
  Mix task for seeding the Neo4J database with family tree data.

  ## Usage

      mix neo4j.seed

  This task will:
  1. Clear existing data in Neo4J
  2. Create database constraints
  3. Load family data from priv/family_data/context.json
  4. Create Person nodes for all family members
  5. Create relationships (PARENT_OF, MARRIED_TO)
  6. Verify the seeded data

  ## Options

      --verify-only    Only run verification queries without seeding
      --clear-only     Only clear the database without seeding new data

  ## Examples

      # Full seeding process
      mix neo4j.seed

      # Only verify existing data
      mix neo4j.seed --verify-only

      # Only clear the database
      mix neo4j.seed --clear-only

  """

  use Mix.Task

  alias FamilyTreeAgent.Data.Neo4jSeeder

  @shortdoc "Seeds the Neo4J database with family tree data"

  @impl Mix.Task
  def run(args) do
    # Start the application to ensure dependencies are loaded
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          verify_only: :boolean,
          clear_only: :boolean
        ]
      )

    cond do
      opts[:verify_only] ->
        run_verification()

      opts[:clear_only] ->
        run_clear_only()

      true ->
        run_full_seed()
    end
  end

  defp run_verification do
    Mix.shell().info("🔍 Verifying Neo4J database data...")
    Neo4jSeeder.verify_seeded_data()
    Mix.shell().info("✅ Verification completed!")
  end

  defp run_clear_only do
    Mix.shell().info("🧹 Clearing Neo4J database...")

    case Neo4jSeeder.clear_database() do
      :ok ->
        Mix.shell().info("✅ Database cleared successfully!")

      {:error, reason} ->
        Mix.shell().error("❌ Failed to clear database: #{reason}")
        System.halt(1)
    end
  end

  defp run_full_seed do
    Mix.shell().info("🌱 Starting Neo4J database seeding process...")

    case Neo4jSeeder.seed_database() do
      :ok ->
        Mix.shell().info("✅ Neo4J database seeding completed successfully!")

        # Verify the seeded data
        Mix.shell().info("\n🔍 Verifying seeded data...")
        Neo4jSeeder.verify_seeded_data()

        Mix.shell().info(
          "\n🎉 All done! Your Neo4J database is now populated with family tree data."
        )

      {:error, reason} ->
        Mix.shell().error("❌ Neo4J database seeding failed: #{reason}")
        Mix.shell().info("\nPlease check:")
        Mix.shell().info("1. Neo4J is running on localhost:7474")
        Mix.shell().info("2. Database credentials are correct (neo4j:familytree123)")
        Mix.shell().info("3. The family data file exists at priv/family_data/context.json")

        System.halt(1)
    end
  end
end
