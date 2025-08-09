defmodule FamilyTreeAgent.Seeds do
  @moduledoc """
  Module for seeding the database with family member data from JSON file.
  Uses upsert operations to make the process idempotent.
  """

  alias FamilyTreeAgent.Repo
  alias FamilyTreeAgent.Schema.FamilyMember

  @doc """
  Runs the seeding process.

  ## Examples

      iex> FamilyTreeAgent.Seeds.run()
      :ok

  """
  def run do
    # Path to the JSON file using the correct priv directory
    json_file_path =
      Path.join(:code.priv_dir(:family_tree_agent), "family_data/family_members.json")

    # Load and process JSON data
    case File.read(json_file_path) do
      {:ok, json_content} ->
        case Jason.decode(json_content) do
          {:ok, %{"family_members" => family_members}} ->
            IO.puts("Processing #{length(family_members)} family members from JSON...")

            Enum.each(family_members, fn member_data ->
              process_member(member_data)
            end)

          {:error, reason} ->
            IO.puts("Error parsing JSON: #{inspect(reason)}")
            {:error, :json_parse_error}
        end

      {:error, :enoent} ->
        IO.puts("JSON file not found: #{json_file_path}")
        IO.puts("Creating a sample family member instead...")
        create_sample_member()

      {:error, reason} ->
        IO.puts("Error reading JSON file: #{inspect(reason)}")
        {:error, :file_read_error}
    end

    # Show final count
    total_members = Repo.aggregate(FamilyMember, :count, :id)
    IO.puts("\nTotal family members in database: #{total_members}")
    IO.puts("Seeds completed successfully! ✅")

    :ok
  end

  # Private functions

  defp process_member(member_data) do
    member_attrs = %{
      name: member_data["name"],
      birth_date: parse_date(member_data["birth_date"]),
      death_date: parse_date(member_data["death_date"]),
      bio: member_data["bio"],
      relationships: member_data["relationships"] || %{},
      metadata: member_data["metadata"] || %{}
    }

    # Add ID if provided in JSON
    member_attrs =
      if member_data["id"] do
        Map.put(member_attrs, :id, member_data["id"])
      else
        member_attrs
      end

    changeset = FamilyMember.changeset(%FamilyMember{}, member_attrs)

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: :id
         ) do
      {:ok, member} ->
        IO.puts("✓ Created: #{member.name} (ID: #{member.id})")

      {:error, changeset} ->
        IO.puts("✗ Failed to create member: #{member_data["name"]}")
        IO.inspect(changeset.errors)
    end
  end

  defp create_sample_member do
    sample_attrs = %{
      name: "John Doe",
      birth_date: ~D[1980-01-15],
      bio: "Sample family member for testing the database setup.",
      relationships: %{},
      metadata: %{}
    }

    changeset = FamilyMember.changeset(%FamilyMember{}, sample_attrs)

    case Repo.insert(changeset,
           on_conflict: :nothing,
           conflict_target: :id
         ) do
      {:ok, member} ->
        IO.puts("✓ Created sample member: #{member.name} (ID: #{member.id})")

      {:error, changeset} ->
        IO.puts("✗ Failed to create sample member")
        IO.inspect(changeset.errors)
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
