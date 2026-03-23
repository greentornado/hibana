defmodule Hibana.LiveViewTest do
  use ExUnit.Case, async: true

  describe "__using__/1" do
    test "creates default implementations for LiveView callbacks" do
      defmodule TestLiveView do
        use Hibana.LiveView
      end

      assert function_exported?(TestLiveView, :mount, 3)
      assert function_exported?(TestLiveView, :render, 1)
      assert function_exported?(TestLiveView, :handle_event, 3)
      assert function_exported?(TestLiveView, :handle_info, 2)
      assert function_exported?(TestLiveView, :handle_connect, 1)
      assert function_exported?(TestLiveView, :terminate, 2)
    end

    test "default mount returns ok with socket" do
      defmodule TestLiveViewMount do
        use Hibana.LiveView
      end

      socket = Hibana.LiveView.Socket.new(TestLiveViewMount, Hibana.Endpoint)
      {:ok, result_socket} = TestLiveViewMount.mount(%{}, %{}, socket)
      assert %Hibana.LiveView.Socket{} = result_socket
    end

    test "default render returns empty string" do
      defmodule TestLiveViewRender do
        use Hibana.LiveView
      end

      assert TestLiveViewRender.render(%{}) == ""
    end

    test "default handle_event returns noreply with socket" do
      defmodule TestLiveViewEvent do
        use Hibana.LiveView
      end

      socket = Hibana.LiveView.Socket.new(TestLiveViewEvent, Hibana.Endpoint)
      {:noreply, result_socket} = TestLiveViewEvent.handle_event("click", %{}, socket)
      assert %Hibana.LiveView.Socket{} = result_socket
    end

    test "default handle_info returns noreply with socket" do
      defmodule TestLiveViewInfo do
        use Hibana.LiveView
      end

      socket = Hibana.LiveView.Socket.new(TestLiveViewInfo, Hibana.Endpoint)
      {:noreply, result_socket} = TestLiveViewInfo.handle_info(:some_message, socket)
      assert %Hibana.LiveView.Socket{} = result_socket
    end

    test "default handle_connect returns ok with socket" do
      defmodule TestLiveViewConnect do
        use Hibana.LiveView
      end

      socket = Hibana.LiveView.Socket.new(TestLiveViewConnect, Hibana.Endpoint)
      {:ok, result_socket} = TestLiveViewConnect.handle_connect(socket)
      assert %Hibana.LiveView.Socket{} = result_socket
    end

    test "default terminate returns :ok" do
      defmodule TestLiveViewTerminate do
        use Hibana.LiveView
      end

      socket = Hibana.LiveView.Socket.new(TestLiveViewTerminate, Hibana.Endpoint)
      assert TestLiveViewTerminate.terminate(:normal, socket) == :ok
    end

    test "callbacks are overridable" do
      defmodule CustomLiveView do
        use Hibana.LiveView

        def mount(_params, _session, socket) do
          {:ok, assign(socket, count: 0)}
        end

        def render(assigns) do
          "<div>Count: #{assigns[:count]}</div>"
        end

        def handle_event("increment", _params, socket) do
          {:noreply, assign(socket, count: socket.assigns.count + 1)}
        end
      end

      socket = Hibana.LiveView.Socket.new(CustomLiveView, Hibana.Endpoint)
      {:ok, mounted_socket} = CustomLiveView.mount(%{}, %{}, socket)
      assert mounted_socket.assigns[:count] == 0

      assert CustomLiveView.render(%{count: 5}) == "<div>Count: 5</div>"

      {:noreply, event_socket} = CustomLiveView.handle_event("increment", %{}, mounted_socket)
      assert event_socket.assigns[:count] == 1
    end
  end

  describe "Socket" do
    test "creates new socket with defaults" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)

      assert %Hibana.LiveView.Socket{} = socket
      assert socket.assigns == %{}
      assert socket.handler == MyAppLive
      assert socket.endpoint == MyApp.Endpoint
      assert socket.id != nil
      assert socket.connected? == false
    end

    test "assign adds key-value to assigns" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)
      updated_socket = Hibana.LiveView.Socket.assign(socket, :count, 42)

      assert updated_socket.assigns[:count] == 42
    end

    test "push_event adds phx- prefixed key" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)
      updated_socket = Hibana.LiveView.Socket.push_event(socket, "click", %{x: 1})

      assert updated_socket.assigns[:"phx-click"] == %{x: 1}
    end
  end

  describe "helper functions" do
    test "socket/3 creates a new socket" do
      socket = Hibana.LiveView.socket(MyAppLive, MyApp.Endpoint, "custom-id")
      assert socket.id == "custom-id"
    end

    test "connected/1 marks socket as connected" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)
      connected_socket = Hibana.LiveView.connected(socket)

      assert connected_socket.connected? == true
    end

    test "push/3 adds event to assigns" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)
      pushed_socket = Hibana.LiveView.push(socket, "event", %{data: "test"})

      assert pushed_socket.assigns[:"phx-event"] == %{data: "test"}
    end

    test "redirect/2 adds redirect to assigns" do
      socket = Hibana.LiveView.Socket.new(MyAppLive, MyApp.Endpoint)
      redirected_socket = Hibana.LiveView.redirect(socket, to: "/new-path")

      assert redirected_socket.assigns[:__redirect__] == "/new-path"
    end
  end
end
