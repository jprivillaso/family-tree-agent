# Script for populating the database with family member data from JSON file.
# Uses upsert operations to make the process idempotent.
#
# You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Multiple runs are safe - existing records will be skipped, new ones created.

FamilyTreeAgent.Seeds.run()
