defmodule FamilyTreeAgent.Repo.Migrations.CreateFamilyMembers do
  use Ecto.Migration

  def change do
    create table(:family_members, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :birth_date, :date
      add :death_date, :date
      add :bio, :text
      add :relationships, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:family_members, [:name])
  end
end
