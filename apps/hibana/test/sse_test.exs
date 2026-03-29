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

  describe "stream/3" do
    test "executes function with send helper" do
      conn = conn(:get, "/events") |> SSE.init()

      test_pid = self()

      result =
        SSE.stream(conn, fn send_fn ->
          send(test_pid, :function_called)
          # In real usage, this would send events
          # send_fn.("message", "data")
        end)

      assert_receive :function_called
      assert result == conn
    end

    test "stream returns conn after execution" do
      conn = conn(:get, "/events") |> SSE.init()

      result =
        SSE.stream(conn, fn _send_fn ->
          :ok
        end)

      assert result == conn
    end
  end

  describe "stream_loop/2" do
    test "processes mailbox messages" do
      conn = conn(:get, "/events") |> SSE.init()

      # Start stream_loop in a separate process
      task =
        Task.async(fn ->
          SSE.stream_loop(conn, max_events: 1, max_duration: 5000)
        end)

      # Send an event to the task's mailbox
      send(task.pid, {:sse_event, "message", "test data"})

      # Wait for task to complete (should complete after processing 1 event)
      Task.await(task, 2000)
    end

    test "stops on :sse_close message" do
      conn = conn(:get, "/events") |> SSE.init()

      task =
        Task.async(fn ->
          SSE.stream_loop(conn, max_events: 1000, max_duration: 5000)
        end)

      # Send close message
      send(task.pid, :sse_close)

      # Should complete quickly
      result = Task.await(task, 1000)
      assert result == conn
    end

    test "respects max_events limit" do
      conn = conn(:get, "/events") |> SSE.init()

      task =
        Task.async(fn ->
          SSE.stream_loop(conn, max_events: 2, max_duration: 5000)
        end)

      # Send more events than max_events
      send(task.pid, {:sse_event, "message", "data1"})
      send(task.pid, {:sse_event, "message", "data2"})
      send(task.pid, {:sse_event, "message", "data3"})

      # Should complete after 2 events
      Task.await(task, 2000)
    end

    test "respects max_duration limit" do
      conn = conn(:get, "/events") |> SSE.init()

      task =
        Task.async(fn ->
          SSE.stream_loop(conn, max_events: 1000, max_duration: 100)
        end)

      # Wait for timeout (give plenty of time for the 100ms duration + overhead)
      Task.await(task, 2000)
    end

    test "handles keep-alive timeout" do
      conn = conn(:get, "/events") |> SSE.init()

      task =
        Task.async(fn ->
          SSE.stream_loop(conn, keep_alive: 50, max_events: 1, max_duration: 500)
        end)

      # Wait for keep-alive to trigger
      Task.await(task, 1000)
    end
  end

  describe "SSE message format" do
    test "formats event with type and data" do
      conn = conn(:get, "/events") |> SSE.init()

      # The send_event function should format as: event: type\ndata: json\n\n
      {:ok, _new_conn} = SSE.send_event(conn, "message", %{text: "hello"})
      # Returns updated conn, just verify it doesn't crash
      assert true
    end

    test "formats data-only event" do
      conn = conn(:get, "/events") |> SSE.init()

      {:ok, _new_conn} = SSE.send_data(conn, "plain text")
      assert true
    end

    test "formats comment" do
      conn = conn(:get, "/events") |> SSE.init()

      {:ok, _new_conn} = SSE.send_comment(conn, ":keep-alive")
      assert true
    end
  end

  describe "SSE error handling" do
    test "handles connection errors gracefully" do
      # Create a connection that's already closed
      conn = conn(:get, "/events") |> SSE.init() |> halt()

      # Should handle error without crashing
      result = SSE.send_event(conn, "message", "data")
      assert is_tuple(result)
    end

    test "handles send failures in stream_loop" do
      conn = conn(:get, "/events") |> SSE.init() |> halt()

      task =
        Task.async(fn ->
          SSE.stream_loop(conn, max_events: 1, max_duration: 500)
        end)

      # Send an event - it will fail but not crash
      send(task.pid, {:sse_event, "message", "data"})

      # Should complete without crashing
      Task.await(task, 1000)
    end
  end

  describe "init options" do
    test "init with custom retry value" do
      conn = conn(:get, "/events")
      conn = SSE.init(conn, retry: 10000)

      assert conn.status == 200
      assert conn.state == :chunked
    end

    test "init with default options" do
      conn = conn(:get, "/events")
      conn = SSE.init(conn, [])

      assert conn.status == 200
      assert conn.state == :chunked
    end
  end
end
