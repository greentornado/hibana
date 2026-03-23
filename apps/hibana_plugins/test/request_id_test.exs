defmodule Hibana.Plugins.RequestIdTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.RequestId

  describe "init/1" do
    test "sets default options" do
      opts = RequestId.init([])
      assert opts.header == "x-request-id"
      assert opts.generate_if_missing == true
    end

    test "allows custom options" do
      opts = RequestId.init(header: "x-trace-id", generate_if_missing: false)
      assert opts.header == "x-trace-id"
      assert opts.generate_if_missing == false
    end
  end

  describe "call/2" do
    test "generates request id when none provided" do
      opts = %{header: "x-request-id", generate_if_missing: true}
      conn = Plug.Test.conn(:get, "/")

      result = RequestId.call(conn, opts)

      assert result.assigns[:request_id] != nil
      assert is_binary(result.assigns[:request_id])
      assert byte_size(result.assigns[:request_id]) == 32
    end

    test "uses existing request id" do
      opts = %{header: "x-request-id", generate_if_missing: true}

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("x-request-id", "existing-id-123")

      result = RequestId.call(conn, opts)

      assert result.assigns[:request_id] == "existing-id-123"
    end

    test "does not generate when generate_if_missing is false and no id provided" do
      opts = %{header: "x-request-id", generate_if_missing: false}
      conn = Plug.Test.conn(:get, "/")

      result = RequestId.call(conn, opts)

      assert result.assigns[:request_id] == nil
    end

    test "adds request id to response header" do
      opts = %{header: "x-request-id", generate_if_missing: true}
      conn = Plug.Test.conn(:get, "/")

      result = RequestId.call(conn, opts)

      assert {"x-request-id", _} =
               Enum.find(result.resp_headers, fn {k, _} -> k == "x-request-id" end)
    end

    test "handles empty string request id" do
      opts = %{header: "x-request-id", generate_if_missing: true}

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("x-request-id", "")

      result = RequestId.call(conn, opts)

      assert result.assigns[:request_id] != nil
      assert byte_size(result.assigns[:request_id]) == 32
    end
  end
end
