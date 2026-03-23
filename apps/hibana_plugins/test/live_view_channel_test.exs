defmodule Hibana.Plugins.LiveViewTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns options with handler" do
      handler = fn _ -> "test" end
      opts = Hibana.Plugins.LiveView.init(handler: handler)
      assert opts.handler == handler
    end
  end

  describe "call/2" do
    test "returns conn for non-liveview path" do
      conn = Plug.Test.conn(:get, "/users")

      handler = fn _ -> "test" end
      opts = %{handler: handler}
      result = Hibana.Plugins.LiveView.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "requires upgrade header for websocket" do
      conn =
        Plug.Test.conn(:get, "/lv/socket")
        |> Plug.Conn.put_req_header("upgrade", "http")

      handler = fn _ -> "test" end
      opts = %{handler: handler}
      result = Hibana.Plugins.LiveView.call(conn, opts)
      assert result.status == 426
      assert result.halted == true
    end
  end

  describe "build_socket/3" do
    test "creates a new socket" do
      socket = Hibana.Plugins.LiveView.build_socket(__MODULE__, __MODULE__)
      assert %Hibana.LiveView.Socket{} = socket
      assert socket.endpoint == __MODULE__
      assert socket.handler == __MODULE__
    end

    test "accepts custom id" do
      socket = Hibana.Plugins.LiveView.build_socket(__MODULE__, __MODULE__, "custom-id")
      assert socket.id == "custom-id"
    end
  end

  describe "handle_event/4" do
    test "delegates to handler" do
      defmodule TestLiveViewHandler do
        def handle_event(event, params, socket) do
          {:noreply, Hibana.LiveView.Socket.assign(socket, :event, event)}
        end
      end

      socket = Hibana.LiveView.Socket.new(__MODULE__, __MODULE__)
      result = Hibana.Plugins.LiveView.handle_event(socket, "click", %{}, TestLiveViewHandler)
      assert {:noreply, _} = result
    end
  end

  describe "render/2" do
    test "renders using handler" do
      defmodule TestLiveViewRenderer do
        def render(assigns) do
          "<div>#{assigns[:count]}</div>"
        end
      end

      socket = Hibana.LiveView.Socket.new(__MODULE__, __MODULE__)
      socket = Hibana.LiveView.Socket.assign(socket, :count, 42)
      result = Hibana.Plugins.LiveView.render(socket, TestLiveViewRenderer)
      assert result == "<div>42</div>"
    end
  end
end
