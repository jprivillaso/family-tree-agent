defmodule FamilyTreeAgent.Schema.FamilyMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "family_members" do
    field :name, :string
    field :birth_date, :date
    field :death_date, :date
    field :bio, :string
    field :relationships, :map, default: %{}
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(family_member, attrs) do
    family_member
    |> cast(attrs, [:name, :birth_date, :death_date, :bio, :relationships, :metadata])
    |> validate_required([:name])
    |> validate_birth_death_dates()
  end

  defp validate_birth_death_dates(changeset) do
    birth_date = get_field(changeset, :birth_date)
    death_date = get_field(changeset, :death_date)

    if birth_date && death_date && Date.compare(birth_date, death_date) == :gt do
      add_error(changeset, :death_date, "must be after birth date")
    else
      changeset
    end
  end
end
