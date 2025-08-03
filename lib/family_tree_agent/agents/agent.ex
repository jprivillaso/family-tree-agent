defmodule FamilyTreeAgent.Agents.Agent do
  @moduledoc """
  Agent module for the family tree agent that provides AI-powered responses about family members.
  """

  alias FamilyTreeAgent.Data.FamilyTree
  alias OpenaiEx

  @doc """
  Answers questions about a specific family member using OpenAI GPT-4.1.

  ## Parameters

  - `person_name` - The name of the person to ask about
  - `question` - The question to ask about the person

  ## Examples

      iex> answer_question("John Doe", "What is his occupation?")
      {:ok, "John Doe is a Software Engineer according to his profile."}

      iex> answer_question("Unknown Person", "What is their age?")
      {:error, "Person not found"}
  """
  def answer_question(person_name, question) do
    case find_person(person_name) do
      [] ->
        {:error, "Person not found. No family member found with the name '#{person_name}'."}

      [person] ->
        generate_answer(person, question)

      multiple_people ->
        person_names = Enum.map(multiple_people, & &1.name)
        {:error, "Multiple people found with similar names: #{Enum.join(person_names, ", ")}. Please be more specific."}
    end
  end

  @doc """
  Answers general questions about the family tree.

  ## Parameters

  - `question` - The general question about the family

  ## Examples

      iex> answer_general_question("How many family members are there?")
      {:ok, "There are 4 family members in the tree."}
  """
  def answer_general_question(question) do
    family_data = FamilyTree.get_family_tree()
    generate_general_answer(family_data, question)
  end

  # Private functions

  defp find_person(name) do
    # Search for exact matches first, then partial matches
    exact_matches = FamilyTree.search_members_by_name(name)

    case exact_matches do
      [] ->
        # Try with partial matching for common variations
        search_variations = [
          String.downcase(name),
          String.trim(name),
          name |> String.split() |> List.first() # First name only
        ]

        Enum.reduce(search_variations, [], fn variation, acc ->
          if acc == [] do
            FamilyTree.search_members_by_name(variation)
          else
            acc
          end
        end)

      results -> results
    end
  end

  defp generate_answer(person, question) do
    system_prompt = """
    You are a helpful family tree assistant. You have access to detailed information about a family member.

    When answering questions:
    1. Use only the information provided about the person
    2. Be conversational and friendly
    3. If the information isn't available, say so politely
    4. Include relevant details from their bio, relationships, and metadata
    5. Format dates in a human-readable way
    6. Be specific about relationships (e.g., "John's wife Jane" instead of just "Jane")
    """

    person_context = format_person_context(person)

    user_prompt = """
    Here is the information about #{person.name}:

    #{person_context}

    Question: #{question}

    Please provide a helpful and informative answer based on this information.
    """

    case call_openai(system_prompt, user_prompt) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, "Failed to generate answer: #{error}"}
    end
  end

  defp generate_general_answer(family_data, question) do
    system_prompt = """
    You are a helpful family tree assistant. You have access to information about an entire family tree.

    When answering questions:
    1. Use only the information provided about the family
    2. Be conversational and friendly
    3. Provide specific details when available
    4. Help identify relationships and connections
    5. Count and summarize information when relevant
    """

    family_context = format_family_context(family_data)

    user_prompt = """
    Here is the information about the family tree:

    #{family_context}

    Question: #{question}

    Please provide a helpful and informative answer based on this information.
    """

    case call_openai(system_prompt, user_prompt) do
      {:ok, response} -> {:ok, response}
      {:error, error} -> {:error, "Failed to generate answer: #{error}"}
    end
  end

  defp format_person_context(person) do
    """
    Name: #{person.name}
    Birth Date: #{format_date_for_ai(person.birth_date)}
    Death Date: #{format_date_for_ai(person.death_date) || "Still alive"}
    Bio: #{person.bio || "No bio available"}

    Relationships:
    #{format_relationships(person.relationships)}

    Additional Information:
    #{format_metadata(person.metadata)}
    """
  end

  defp format_family_context(family_data) do
    """
    Total Family Members: #{family_data.total_members}

    Family Members:
    #{format_family_members(family_data.members)}
    """
  end

  defp format_family_members(members) do
    Enum.map(members, fn member ->
      """
      - #{member.name} (#{member.birth_date || "unknown"} - #{member.death_date || "present"})
        Bio: #{member.bio || "No bio available"}
        Relationships: #{format_relationships(member.relationships)}
        Additional: #{format_metadata(member.metadata)}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_relationships(relationships) when is_map(relationships) do
    relationships
    |> Enum.map(fn {key, value} ->
      case value do
        list when is_list(list) ->
          "#{key}: #{Enum.join(list, ", ")}"
        single when is_binary(single) ->
          "#{key}: #{single}"
        _ ->
          "#{key}: #{inspect(value)}"
      end
    end)
    |> Enum.join(", ")
  end

  defp format_relationships(_), do: "No relationships recorded"

  defp format_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {key, value} ->
      case value do
        list when is_list(list) ->
          "#{key}: #{Enum.join(list, ", ")}"
        single ->
          "#{key}: #{single}"
      end
    end)
    |> Enum.join(", ")
  end

  defp format_metadata(_), do: "No additional information available"

  defp format_date_for_ai(nil), do: nil
  defp format_date_for_ai(date), do: Date.to_iso8601(date)

    defp call_openai(system_prompt, user_prompt) do
    openai_config = Application.get_env(:family_tree_agent, :openai, [])
    api_key = Keyword.get(openai_config, :api_key) || System.get_env("OPENAI_API_KEY")

    if api_key do
      alias OpenaiEx.Chat
      alias OpenaiEx.ChatMessage

      client = OpenaiEx.new(api_key)

      messages = [
        ChatMessage.system(system_prompt),
        ChatMessage.user(user_prompt)
      ]

      request = Chat.Completions.new(
        model: "gpt-4o", # Using gpt-4o as it's the latest GPT-4 model
        messages: messages,
        max_tokens: 500,
        temperature: 0.7
      )

      case Chat.Completions.create(client, request) do
        {:ok, %{"choices" => [%{"message" => %{"content" => content}} | _]}} ->
          {:ok, String.trim(content)}

        {:error, error} ->
          {:error, "OpenAI API error: #{inspect(error)}"}
      end
    else
      {:error, "OpenAI API key not configured"}
    end
  end
end
