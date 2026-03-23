defmodule Hibana.Plugins.DevErrorPageTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.DevErrorPage

  describe "init/1" do
    test "defaults enabled to true" do
      opts = DevErrorPage.init([])
      assert opts.enabled == true
    end

    test "can be disabled" do
      opts = DevErrorPage.init(enabled: false)
      assert opts.enabled == false
    end
  end

  describe "call/2" do
    test "does not halt connection when enabled" do
      opts = DevErrorPage.init([])

      conn =
        Plug.Test.conn(:get, "/test")
        |> DevErrorPage.call(opts)

      refute conn.halted
    end

    test "passes through when disabled" do
      opts = DevErrorPage.init(enabled: false)

      conn =
        Plug.Test.conn(:get, "/test")
        |> DevErrorPage.call(opts)

      refute conn.halted
      # When disabled, the conn is returned unchanged
      assert conn.status == nil
    end
  end

  describe "render_exception/4" do
    test "produces HTML with error information" do
      conn = Plug.Test.conn(:get, "/broken")

      try do
        raise "something went wrong"
      rescue
        e ->
          result = DevErrorPage.render_exception(conn, :error, e, __STACKTRACE__)
          assert result.status == 500
          assert result.halted
          assert result.resp_body =~ "something went wrong"
          assert result.resp_body =~ "RuntimeError"
          assert result.resp_body =~ "Stack Trace"
          assert result.resp_body =~ "/broken"
      end
    end
  end
end
