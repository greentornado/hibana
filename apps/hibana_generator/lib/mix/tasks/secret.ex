defmodule Mix.Tasks.Secret do
  use Mix.Task

  @shortdoc "Generate a secret key"

  @moduledoc """
  Generates a secret key for your application.

      mix secret

  ## Options

  - `--length` - Length of the secret (default: 64)

  ## Examples

      mix secret
      mix secret --length 32

  This generates a random base64 string suitable for use as a secret_key_base.
  """

  @doc """
  Generates and prints a random secret key.

  ## Parameters

    - `args` - Command-line arguments with optional `--length` flag
  """
  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [length: :integer])

    length = opts[:length] || 64

    secret = :crypto.strong_rand_bytes(length) |> Base.encode64()

    Mix.shell().info("")
    Mix.shell().info("Secret key generated:")
    Mix.shell().info(secret)
    Mix.shell().info("")
    Mix.shell().info("Add to your config:")
    Mix.shell().info("")
    Mix.shell().info("    config :my_app, secret_key_base: \"#{secret}\"")
    Mix.shell().info("")
  end
end
