#!/usr/bin/env elixir

# Test script for AI clients
# Usage: elixir scripts/test_ai_clients.exs

Mix.install([
  {:family_tree_agent, path: "."}
])

defmodule AIClientTest do
  alias FamilyTreeAgent.AI.Clients.Client

  def run do
    IO.puts("🧪 Testing AI Client System")
    IO.puts("=" |> String.duplicate(50))

    # Test client factory info
    test_client_info()

    # Test client creation
    test_client_creation()

    # Test basic functionality (if API key is available)
    test_basic_functionality()

    IO.puts("\n✅ All tests completed!")
  end

  defp test_client_info do
    IO.puts("\n📋 Testing Client.client_info/0...")

    info = Client.client_info()
    IO.puts("Current client type: #{info.current_type}")
    IO.puts("Available types: #{inspect(info.available_types)}")
    IO.puts("Config: #{inspect(info.config)}")
  end

  defp test_client_creation do
    IO.puts("\n🏗️  Testing client creation...")

    # Test default client
    case Client.create() do
      {:ok, client} ->
        provider = Client.provider(client)
        IO.puts("✅ Default client created: #{provider}")
        client_info = Client.info(client)
        IO.puts("   Provider: #{client_info.provider}")
        IO.puts("   Embedding model: #{client_info.embedding_model}")
        IO.puts("   Chat model: #{client_info.chat_model}")

      {:error, reason} ->
        IO.puts("❌ Failed to create default client: #{reason}")
    end

    # Test specific client types
    for client_type <- Client.available_client_types() do
      case Client.create(client_type) do
        {:ok, client} ->
          IO.puts("✅ #{client_type} client created successfully")

        {:error, reason} ->
          IO.puts("⚠️  #{client_type} client failed: #{reason}")
      end
    end
  end

  defp test_basic_functionality do
    IO.puts("\n🔧 Testing basic functionality...")

    case Client.create() do
      {:ok, client} ->
        test_text = "Hello, this is a test."

        IO.puts("Testing with: '#{test_text}'")

        # Test embedding (should work for both clients)
        try do
          embedding = Client.create_embedding(client, test_text)
          shape = Nx.shape(embedding)
          IO.puts("✅ Embedding created: #{inspect(shape)} tensor")
        rescue
          error ->
            IO.puts("❌ Embedding failed: #{Exception.message(error)}")
        end

        # Test text generation (might fail without proper setup)
        try do
          case Client.generate_text(client, "What is 2+2?") do
            {:ok, response} ->
              IO.puts("✅ Text generation successful: #{String.slice(response, 0, 50)}...")

            {:error, reason} ->
              IO.puts("⚠️  Text generation failed: #{reason}")
          end
        rescue
          error ->
            IO.puts("❌ Text generation error: #{Exception.message(error)}")
        end

      {:error, reason} ->
        IO.puts("❌ Could not create client for testing: #{reason}")
    end
  end
end

# Run the test
AIClientTest.run()
