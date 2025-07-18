defmodule FamilyTreeAgent.FamilyTree do
  @moduledoc """
  Context module for managing family tree data and operations using the database.
  """

  import Ecto.Query, warn: false

  alias FamilyTreeAgent.Repo
  alias FamilyTreeAgent.Schema.FamilyMember

  @doc """
  Returns the list of family members.

  ## Examples

      iex> list_members()
      [%FamilyMember{}, ...]

  """
  def list_members do
    Repo.all(FamilyMember)
  end

  @doc """
  Gets a single family member.

  Raises `Ecto.NoResultsError` if the Family member does not exist.

  ## Examples

      iex> get_member!(123)
      %FamilyMember{}

      iex> get_member!(456)
      ** (Ecto.NoResultsError)

  """
  def get_member!(id), do: Repo.get!(FamilyMember, id)

  @doc """
  Gets a single family member.

  Returns `nil` if the Family member does not exist.

  ## Examples

      iex> get_member(123)
      %FamilyMember{}

      iex> get_member(456)
      nil

  """
  def get_member(id), do: Repo.get(FamilyMember, id)

  @doc """
  Creates a family member.

  ## Examples

      iex> create_member(%{field: value})
      {:ok, %FamilyMember{}}

      iex> create_member(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_member(attrs \\ %{}) do
    %FamilyMember{}
    |> FamilyMember.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a family member.

  ## Examples

      iex> update_member(family_member, %{field: new_value})
      {:ok, %FamilyMember{}}

      iex> update_member(family_member, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_member(%FamilyMember{} = family_member, attrs) do
    family_member
    |> FamilyMember.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a family member.

  ## Examples

      iex> delete_member(family_member)
      {:ok, %FamilyMember{}}

      iex> delete_member(family_member)
      {:error, %Ecto.Changeset{}}

  """
  def delete_member(%FamilyMember{} = family_member) do
    Repo.delete(family_member)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking family member changes.

  ## Examples

      iex> change_member(family_member)
      %Ecto.Changeset{data: %FamilyMember{}}

  """
  def change_member(%FamilyMember{} = family_member, attrs \\ %{}) do
    FamilyMember.changeset(family_member, attrs)
  end

  @doc """
  Gets the complete family tree structure with relationships.

  ## Examples

      iex> get_family_tree()
      %{
        total_members: 5,
        members: [%FamilyMember{}, ...],
        relationships: %{...},
        generations: [...]
      }

  """
  def get_family_tree do
    members = list_members()

    %{
      total_members: length(members),
      members: format_members_for_json(members),
      relationships: build_relationships_map(members),
      generations: build_generations(members)
    }
  end

  @doc """
  Searches family members by name.

  ## Examples

      iex> search_members_by_name("John")
      [%FamilyMember{name: "John Doe"}, ...]

  """
  def search_members_by_name(name) do
    query = from m in FamilyMember,
            where: ilike(m.name, ^"%#{name}%"),
            order_by: m.name

    Repo.all(query)
  end

  # Private functions

  defp format_members_for_json(members) do
    Enum.map(members, fn member ->
      %{
        id: member.id,
        name: member.name,
        birth_date: format_date(member.birth_date),
        death_date: format_date(member.death_date),
        bio: member.bio,
        relationships: member.relationships,
        metadata: member.metadata,
        inserted_at: member.inserted_at,
        updated_at: member.updated_at
      }
    end)
  end

  defp format_date(nil), do: nil
  defp format_date(date), do: Date.to_iso8601(date)

  defp build_relationships_map(members) do
    members
    |> Enum.reduce(%{}, fn member, acc ->
      Map.put(acc, member.id, member.relationships)
    end)
  end

  defp build_generations(members) do
    # Basic generation building - can be enhanced later
    members
    |> Enum.group_by(fn member ->
      case member.birth_date do
        nil -> "Unknown"
        date -> "#{div(date.year, 10) * 10}s"
      end
    end)
    |> Enum.map(fn {decade, members} ->
      %{
        decade: decade,
        count: length(members),
        members: Enum.map(members, & &1.id)
      }
    end)
    |> Enum.sort_by(& &1.decade)
  end
end
