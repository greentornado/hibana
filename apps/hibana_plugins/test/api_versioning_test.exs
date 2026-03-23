defmodule Hibana.Plugins.APIVersioningTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.APIVersioning

  describe "init/1" do
    test "sets default options" do
      opts = APIVersioning.init([])
      assert opts.default == "v1"
      assert opts.strategies == [:path]
      assert opts.versions == ["v1", "v2"]
    end

    test "allows custom options" do
      opts =
        APIVersioning.init(
          default: "v2",
          strategies: [:header, :query],
          versions: ["v1", "v2", "v3"]
        )

      assert opts.default == "v2"
      assert opts.strategies == [:header, :query]
      assert opts.versions == ["v1", "v2", "v3"]
    end
  end

  describe "call/2 - path strategy" do
    test "extracts version from path" do
      opts = %{
        default: "v1",
        strategies: [:path],
        versions: ["v1", "v2"]
      }

      conn = Plug.Test.conn(:get, "/api/v2/users")

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v2"
    end

    test "uses default when not in path" do
      opts = %{
        default: "v1",
        strategies: [:path],
        versions: ["v1", "v2"]
      }

      conn = Plug.Test.conn(:get, "/users")

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v1"
    end

    test "returns default for unknown version" do
      opts = %{
        default: "v1",
        strategies: [:path],
        versions: ["v1", "v2"]
      }

      conn = Plug.Test.conn(:get, "/api/v99/users")

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v1"
    end
  end

  describe "call/2 - header strategy" do
    test "extracts version from accept header" do
      opts = %{
        default: "v1",
        strategies: [:header],
        versions: ["v1", "v2"]
      }

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> Plug.Conn.put_req_header("accept", "application/vnd.elixir-web.v2+json")

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v2"
    end

    test "uses default when no version in header" do
      opts = %{
        default: "v1",
        strategies: [:header],
        versions: ["v1", "v2"]
      }

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> Plug.Conn.put_req_header("accept", "application/json")

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v1"
    end
  end

  describe "call/2 - query strategy" do
    test "extracts version from query param" do
      opts = %{
        default: "v1",
        strategies: [:query],
        versions: ["v1", "v2"]
      }

      conn = Plug.Test.conn(:get, "/api/users?version=v2")
      conn = Map.put(conn, :query_params, %{"version" => "v2"})

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v2"
    end

    test "uses default when no query param" do
      opts = %{
        default: "v1",
        strategies: [:query],
        versions: ["v1", "v2"]
      }

      conn = Plug.Test.conn(:get, "/api/users")
      conn = Map.put(conn, :query_params, %{})

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v1"
    end
  end

  describe "call/2 - multiple strategies" do
    test "uses first matching strategy" do
      opts = %{
        default: "v1",
        strategies: [:header, :query, :path],
        versions: ["v1", "v2"]
      }

      conn =
        Plug.Test.conn(:get, "/api/v3/users?version=v2")
        |> Plug.Conn.put_req_header("accept", "application/vnd.elixir-web.v1+json")

      conn = Map.put(conn, :query_params, %{"version" => "v2"})

      result = APIVersioning.call(conn, opts)

      assert result.assigns[:api_version] == "v1"
    end
  end

  describe "get_version/1" do
    test "returns version from assigns" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.assign(:api_version, "v2")

      assert APIVersioning.get_version(conn) == "v2"
    end

    test "returns default when no version in assigns" do
      conn = Plug.Test.conn(:get, "/")

      assert APIVersioning.get_version(conn) == "v1"
    end
  end
end
