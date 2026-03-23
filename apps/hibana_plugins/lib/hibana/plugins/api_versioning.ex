defmodule Hibana.Plugins.APIVersioning do
  @moduledoc """
  API Versioning plugin for versioned REST APIs.

  ## Features

  - Multiple versioning strategies (path, header, query)
  - Configurable default version
  - Available in conn.assigns
  - Validates against known versions

  ## Usage

      # Path-based versioning (default)
      plug Hibana.Plugins.APIVersioning

      # Multiple strategies
      plug Hibana.Plugins.APIVersioning,
        default: "v1",
        strategies: [:path, :header, :query]

  ## Versioning Strategies

  ### Path Strategy (default)
  Version in URL path:

      GET /api/v1/users
      GET /api/v2/users

  ### Header Strategy
  Version via Accept header:

      Accept: application/vnd.elixir-web.v1+json
      Accept: application/vnd.elixir-web.v2+json

  ### Query Strategy
  Version via query parameter:

      GET /api/users?version=v1

  ## Options

  - `:default` - Default API version (default: `"v1"`)
  - `:strategies` - List of strategies to use (default: `[:path]`)
  - `:versions` - List of valid versions (default: `["v1", "v2"]`)

  ## Conn Assignments

  After version extraction:

      conn.assigns.api_version  # => "v2"

  ## Module Function

  ### get_version/1
  Get the current API version from connection:

      version = Hibana.Plugins.APIVersioning.get_version(conn)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      default: Keyword.get(opts, :default, "v1"),
      strategies: Keyword.get(opts, :strategies, [:path]),
      versions: Keyword.get(opts, :versions, ["v1", "v2"])
    }
  end

  @impl true
  def call(conn, %{strategies: strategies, default: default, versions: versions}) do
    version = extract_version(conn, strategies, default, versions)
    assign(conn, :api_version, version)
  end

  defp extract_version(conn, strategies, default, versions) do
    Enum.reduce(strategies, nil, fn strategy, acc ->
      acc ||
        case strategy do
          :path ->
            case conn.path_info do
              ["api", v | _] ->
                if Enum.member?(versions, v), do: v, else: nil

              _ ->
                nil
            end

          :header ->
            case get_req_header(conn, "accept") do
              [h | _] ->
                case Regex.run(~r/application\/vnd\.elixir-web\.v(\d+)\+json/, h) do
                  [_, v] -> "v#{v}"
                  _ -> nil
                end

              _ ->
                nil
            end

          :query ->
            conn.query_params["version"]

          _ ->
            nil
        end
    end) || default
  end

  @doc """
  Get the current API version from connection.
  """
  def get_version(conn) do
    Map.get(conn.assigns, :api_version, "v1")
  end
end
