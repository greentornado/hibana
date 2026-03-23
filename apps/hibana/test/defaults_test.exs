defmodule Hibana.Plug.DefaultsTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns options unchanged" do
      opts = [custom: "option"]
      assert Hibana.Plug.Defaults.init(opts) == opts
    end
  end

  describe "call/2" do
    test "fetches query params" do
      conn = Plug.Test.conn(:get, "/?page=1")

      result = Hibana.Plug.Defaults.call(conn, [])
      assert result.params == %{"page" => "1"}
    end

    test "assigns params to conn" do
      conn = Plug.Test.conn(:get, "/?name=test")

      result = Hibana.Plug.Defaults.call(conn, [])
      assert result.assigns[:params] != nil
    end
  end
end
