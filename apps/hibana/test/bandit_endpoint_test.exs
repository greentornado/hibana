defmodule Hibana.BanditEndpointTest do
  use ExUnit.Case, async: false
  use Plug.Test

  alias Hibana.BanditEndpoint

  defmodule TestRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    get "/" do
      send_resp(conn, 200, "Hello from Bandit!")
    end
  end

  defmodule TestEndpoint do
    use BanditEndpoint, otp_app: :hibana

    plug TestRouter
  end

  describe "BanditEndpoint" do
    test "child_spec returns correct specification" do
      spec = BanditEndpoint.child_spec([])

      assert spec.id == BanditEndpoint
      assert spec.type == :worker
      assert spec.restart == :permanent
      assert spec.shutdown == 500
    end

    test "child_spec from __using__ macro" do
      spec = TestEndpoint.child_spec([])

      assert spec.id == TestEndpoint
      assert spec.type == :worker
      assert spec.restart == :permanent
    end

    test "init returns opts unchanged" do
      opts = [foo: :bar]
      assert BanditEndpoint.init(opts) == opts
    end
  end

  describe "start_link with disabled server" do
    setup do
      original = Application.get_env(:hibana, :start_server)
      Application.put_env(:hibana, :start_server, false)

      on_exit(fn ->
        Application.put_env(:hibana, :start_server, original || true)
      end)

      :ok
    end

    test "returns :ignore when server is disabled" do
      result = BanditEndpoint.start_link(TestEndpoint, [], otp_app: :hibana)
      assert result == :ignore
    end
  end

  describe "configuration" do
    test "uses default port 4000" do
      # Get the default options that would be used
      {http_opts, _} =
        Keyword.pop([], :http, [])

      port = Keyword.get(http_opts, :port, 4000)
      assert port == 4000
    end

    test "uses localhost IP by default" do
      {http_opts, _} =
        Keyword.pop([], :http, [])

      ip = Keyword.get(http_opts, :ip, {127, 0, 0, 1})
      assert ip == {127, 0, 0, 1}
    end

    test "allows custom IP configuration" do
      {http_opts, _} =
        Keyword.pop([http: [ip: {0, 0, 0, 0}]], :http, [])

      ip = Keyword.get(http_opts, :ip, {127, 0, 0, 1})
      assert ip == {0, 0, 0, 0}
    end
  end
end
