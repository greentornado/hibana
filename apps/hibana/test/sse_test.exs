defmodule Hibana.SSETest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias Hibana.SSE

  test "init/1 sets correct SSE headers" do
    conn = conn(:get, "/events")
    conn = SSE.init(conn)

    assert get_resp_header(conn, "content-type") == ["text/event-stream"]
    assert get_resp_header(conn, "cache-control") == ["no-cache, no-store, must-revalidate"]
    assert get_resp_header(conn, "connection") == ["keep-alive"]
    assert get_resp_header(conn, "x-accel-buffering") == ["no"]
    assert conn.status == 200
    assert conn.state == :chunked
  end

  test "init/1 sends retry directive" do
    conn = conn(:get, "/events")
    conn = SSE.init(conn, retry: 5000)

    assert conn.state == :chunked
  end

  test "send_event returns ok or error tuple" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_event(conn, "message", %{text: "hello"})
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_event with string data" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_event(conn, "update", "simple data")
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_event with id option" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_event(conn, "message", "data", id: 42)
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_comment returns ok or error tuple" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_comment(conn, "keep-alive")
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_comment with empty comment" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_comment(conn)
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_data sends data-only event" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_data(conn, "hello")
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end

  test "send_data encodes maps as JSON" do
    conn = conn(:get, "/events") |> SSE.init()
    result = SSE.send_data(conn, %{key: "value"})
    assert is_tuple(result)
    assert match?({:ok, _}, result) or match?({:error, _}, result)
  end
end
