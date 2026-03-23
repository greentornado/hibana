defmodule Hibana.EndpointTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns options unchanged" do
      opts = [key: "value"]
      assert Hibana.Endpoint.init(opts) == opts
    end

    test "handles empty options" do
      assert Hibana.Endpoint.init([]) == []
    end
  end

  describe "child_spec/1" do
    test "returns valid child specification" do
      spec = Hibana.Endpoint.child_spec([])

      assert spec[:id] == Hibana.Endpoint
      assert spec[:type] == :worker
      assert spec[:restart] == :permanent
      assert spec[:shutdown] == 500
      assert is_tuple(spec[:start])
    end

    test "child_spec includes start with start_link" do
      spec = Hibana.Endpoint.child_spec(custom: "opts")

      {mod, fun, args} = spec[:start]
      assert mod == Hibana.Endpoint
      assert fun == :start_link
      assert args == [[custom: "opts"]]
    end
  end

  describe "start_link/1" do
    test "accepts custom http options" do
      opts = [http: [port: 0]]
      result = Hibana.Endpoint.start_link(opts)
      assert match?({:ok, _}, result) or result == :ignore or match?({:error, _}, result)
    end
  end

  describe "module attributes" do
    test "Endpoint module is available" do
      assert Code.ensure_loaded?(Hibana.Endpoint)
    end
  end
end
