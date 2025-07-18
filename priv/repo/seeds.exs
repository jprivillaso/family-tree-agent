# Script for populating the database with family member data from markdown files.
#
# You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     FamilyTreeAgent.Repo.insert!(%FamilyTreeAgent.Schema.FamilyMember{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FamilyTreeAgent.Repo
alias FamilyTreeAgent.Schema.FamilyMember

# Define the directory where markdown files are stored
family_data_dir = "priv/family_data"

# Function to parse markdown content and extract family member data
defmodule SeedHelper do
  def parse_markdown_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Extract basic information
        name = extract_name_from_markdown(lines)
        birth_date = extract_field_from_markdown(lines, "Birth Date:")
        death_date = extract_field_from_markdown(lines, "Death Date:")
        bio = extract_bio_from_markdown(lines)

        # For now, we'll set empty relationships and metadata
        # These can be populated in a future enhancement
        %{
          name: name,
          birth_date: parse_date(birth_date),
          death_date: parse_date(death_date),
          bio: bio,
          relationships: %{},
          metadata: %{}
        }

      {:error, reason} ->
        IO.puts("Error reading file #{file_path}: #{inspect(reason)}")
        nil
    end
  end

  defp extract_name_from_markdown(lines) do
    case Enum.find(lines, &String.starts_with?(&1, "# ")) do
      nil -> "Unknown"
      line -> String.trim_leading(line, "# ")
    end
  end

  defp extract_field_from_markdown(lines, field_name) do
    case Enum.find(lines, &String.contains?(&1, field_name)) do
      nil -> nil
      line ->
        value = line |> String.split(field_name) |> List.last() |> String.trim()
        if value == "" or value == "N/A" or value == "nil", do: nil, else: value
    end
  end

  defp extract_bio_from_markdown(lines) do
    bio_start = Enum.find_index(lines, &String.contains?(&1, "## Biography"))
    relationships_start = Enum.find_index(lines, &String.contains?(&1, "## Relationships"))

    if bio_start && relationships_start do
      bio_lines = lines
      |> Enum.slice((bio_start + 1)..(relationships_start - 1))
      |> Enum.reject(&String.trim(&1) == "")
      |> Enum.join("\n")
      |> String.trim()

      case bio_lines do
        "No biography available." -> nil
        "" -> nil
        bio -> bio
      end
    else
      nil
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

# Clear existing data (optional - uncomment if you want to reset)
# Repo.delete_all(FamilyMember)

# Check if the family data directory exists
if File.exists?(family_data_dir) do
  IO.puts("Loading family members from #{family_data_dir}...")

  # Get all markdown files in the directory
  case File.ls(family_data_dir) do
    {:ok, files} ->
      markdown_files = Enum.filter(files, &String.ends_with?(&1, ".md"))

      IO.puts("Found #{length(markdown_files)} markdown files")

      # Process each markdown file
      Enum.each(markdown_files, fn filename ->
        file_path = Path.join(family_data_dir, filename)

        case SeedHelper.parse_markdown_file(file_path) do
          nil ->
            IO.puts("Skipping #{filename} due to parsing error")

          member_data ->
            case Repo.insert(%FamilyMember{
              name: member_data.name,
              birth_date: member_data.birth_date,
              death_date: member_data.death_date,
              bio: member_data.bio,
              relationships: member_data.relationships,
              metadata: member_data.metadata
            }) do
              {:ok, member} ->
                IO.puts("✓ Created: #{member.name} (ID: #{member.id})")

              {:error, changeset} ->
                IO.puts("✗ Failed to create member from #{filename}")
                IO.inspect(changeset.errors)
            end
        end
      end)

    {:error, reason} ->
      IO.puts("Error reading directory #{family_data_dir}: #{inspect(reason)}")
  end
else
  IO.puts("Family data directory #{family_data_dir} does not exist.")
  IO.puts("Creating a sample family member instead...")

  # Create a sample family member
  case Repo.insert(%FamilyMember{
    name: "John Doe",
    birth_date: ~D[1980-01-15],
    bio: "Sample family member for testing the database setup.",
    relationships: %{},
    metadata: %{}
  }) do
    {:ok, member} ->
      IO.puts("✓ Created sample member: #{member.name} (ID: #{member.id})")

    {:error, changeset} ->
      IO.puts("✗ Failed to create sample member")
      IO.inspect(changeset.errors)
  end
end

# Show final count
total_members = Repo.aggregate(FamilyMember, :count, :id)
IO.puts("\nTotal family members in database: #{total_members}")
