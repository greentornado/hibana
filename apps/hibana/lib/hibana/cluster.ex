defmodule Hibana.Cluster do
  @moduledoc """
  Built-in cluster support with node discovery, distributed PubSub, and process distribution.

  ## Usage

      # In your application supervisor
      children = [
        {Hibana.Cluster, strategy: :gossip, port: 45892},
        # or
        {Hibana.Cluster, strategy: :epmd, hosts: [:"app@node1", :"app@node2"]},
        # or
        {Hibana.Cluster, strategy: :dns, query: "app.local"}
      ]

  ## Distributed PubSub

      # Subscribe to a topic
      Hibana.Cluster.subscribe("events")

      # Publish to all nodes
      Hibana.Cluster.broadcast("events", {:new_event, data})

      # Receive in subscribed processes
      receive do
        {:cluster_event, "events", {:new_event, data}} -> handle(data)
      end

  ## Node Discovery Strategies

  - `:epmd` — Connect to known hosts via Erlang distribution
  - `:dns` — Discover nodes via DNS SRV/A records
  - `:gossip` — UDP gossip protocol for automatic discovery

  ## Cluster Info

      Hibana.Cluster.nodes()        # All connected nodes
      Hibana.Cluster.node_count()    # Number of nodes
      Hibana.Cluster.healthy?()      # Cluster health check
  """

  use GenServer
  require Logger

  @registry Hibana.Cluster.PubSub

  @doc """
  Starts the cluster manager GenServer with the given discovery strategy.

  ## Parameters

    - `opts` - Keyword list of options:
      - `:strategy` - Node discovery strategy. Only `:epmd` is fully implemented. 
        `:dns` and `:gossip` fall back to `:epmd` behavior with warnings (default: `:epmd`)
      - `:hosts` - List of node names to connect to for `:epmd` strategy (default: `[]`)
      - `:heartbeat_interval` - Interval in ms between reconnection attempts (default: `5_000`)

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      # Fully supported
      Hibana.Cluster.start_link(strategy: :epmd, hosts: [:"app@node1", :"app@node2"])
      
      # Not yet implemented - falls back to epmd with warning
      Hibana.Cluster.start_link(strategy: :gossip, port: 45892)
      ```
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    # Start PubSub registry (idempotent)
    case Registry.start_link(keys: :duplicate, name: @registry) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end

    strategy = Keyword.get(opts, :strategy, :epmd)
    hosts = Keyword.get(opts, :hosts, [])
    interval = Keyword.get(opts, :heartbeat_interval, 5_000)

    # Validate and warn about unimplemented strategies
    state =
      case strategy do
        :epmd ->
          %{
            strategy: strategy,
            hosts: hosts,
            interval: interval,
            connected: MapSet.new()
          }

        :dns ->
          require Logger

          Logger.warning(
            "[Cluster] :dns strategy is not fully implemented. Falling back to :epmd behavior."
          )

          %{
            # Fall back to epmd
            strategy: :epmd,
            hosts: hosts,
            interval: interval,
            connected: MapSet.new()
          }

        :gossip ->
          require Logger

          Logger.warning(
            "[Cluster] :gossip strategy is not fully implemented. Falling back to :epmd behavior."
          )

          %{
            # Fall back to epmd
            strategy: :epmd,
            hosts: hosts,
            interval: interval,
            connected: MapSet.new()
          }

        other ->
          raise ArgumentError,
                "Unknown cluster strategy: #{inspect(other)}. Supported: :epmd (default). :dns and :gossip fall back to epmd with warnings."
      end

    # Connect to known hosts
    if strategy == :epmd and hosts != [] do
      Enum.each(hosts, &Node.connect/1)
    end

    # Monitor node events (only if distributed)
    if Node.alive?() do
      :net_kernel.monitor_nodes(true)
    end

    # Schedule heartbeat
    Process.send_after(self(), :heartbeat, interval)

    {:ok, state}
  end

  # --- Public API ---

  @doc """
  Returns a list of all connected nodes, including the current node.

  ## Returns

  A list of node atoms.

  ## Examples

      ```elixir
      Hibana.Cluster.nodes()
      # => [:"app@node1", :"app@node2"]
      ```
  """
  def nodes do
    [Node.self() | Node.list()]
  end

  @doc """
  Returns the number of connected nodes (including the current node).

  ## Returns

  An integer count.

  ## Examples

      ```elixir
      Hibana.Cluster.node_count()
      # => 3
      ```
  """
  def node_count do
    length(Node.list()) + 1
  end

  @doc """
  Checks if the cluster is healthy (i.e., the current node is alive and distributed).

  ## Returns

  `true` if `Node.alive?/0` returns true, `false` otherwise.

  ## Examples

      ```elixir
      Hibana.Cluster.healthy?()
      # => true
      ```
  """
  def healthy? do
    Node.alive?()
  end

  @doc """
  Subscribes the current process to a PubSub topic.

  The process will receive `{:cluster_event, topic, message}` tuples
  when messages are broadcast to the topic.

  ## Parameters

    - `topic` - A string topic name

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      Hibana.Cluster.subscribe("chat:lobby")
      # Messages arrive as {:cluster_event, "chat:lobby", payload}
      ```
  """
  def subscribe(topic) do
    Registry.register(@registry, topic, [])
  end

  @doc """
  Unsubscribes the current process from a PubSub topic.

  ## Parameters

    - `topic` - The topic string to unsubscribe from

  ## Returns

  `:ok`
  """
  def unsubscribe(topic) do
    Registry.unregister(@registry, topic)
  end

  @doc """
  Broadcasts a message to all subscribers on all connected nodes.

  Sends the message to local subscribers first, then uses `:rpc.cast/4`
  to broadcast to all remote nodes.

  ## Parameters

    - `topic` - The topic string
    - `message` - Any term to broadcast

  ## Returns

  `:ok`

  ## Examples

      ```elixir
      Hibana.Cluster.broadcast("chat:lobby", %{user: "alice", msg: "hello"})
      ```
  """
  def broadcast(topic, message) do
    # Local broadcast
    local_broadcast(topic, message)

    # Remote broadcast to all connected nodes
    for node <- Node.list() do
      :rpc.cast(node, __MODULE__, :local_broadcast, [topic, message])
    end

    :ok
  end

  @doc """
  Broadcasts a message only to subscribers on the local node.

  ## Parameters

    - `topic` - The topic string
    - `message` - Any term to broadcast
  """
  def local_broadcast(topic, message) do
    Registry.dispatch(@registry, topic, fn entries ->
      for {pid, _} <- entries do
        send(pid, {:cluster_event, topic, message})
      end
    end)
  end

  @doc """
  Calls a function on a specific remote node and waits for the result.

  ## Parameters

    - `node` - The target node atom
    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments
    - `timeout` - Timeout in milliseconds (default: `5_000`)

  ## Returns

  The return value of the remote function call.

  ## Examples

      ```elixir
      Hibana.Cluster.call_on(:"app@node2", MyModule, :get_data, [1])
      ```
  """
  def call_on(node, mod, fun, args, timeout \\ 5_000) do
    :rpc.call(node, mod, fun, args, timeout)
  end

  @doc """
  Casts (fires and forgets) a function call on a specific remote node.

  ## Parameters

    - `node` - The target node atom
    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments

  ## Returns

  `:true` (always, since it's asynchronous).
  """
  def cast_on(node, mod, fun, args) do
    :rpc.cast(node, mod, fun, args)
  end

  @doc """
  Calls a function on all connected nodes and collects the results.

  ## Parameters

    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments
    - `timeout` - Timeout in milliseconds (default: `5_000`)

  ## Returns

  A tuple `{results, bad_nodes}` where `results` is a list of return values
  and `bad_nodes` is a list of nodes that failed to respond.

  ## Examples

      ```elixir
      {results, bad_nodes} = Hibana.Cluster.multicall(MyModule, :get_stats, [])
      ```
  """
  def multicall(mod, fun, args, timeout \\ 5_000) do
    :rpc.multicall(nodes(), mod, fun, args, timeout)
  end

  # --- GenServer callbacks ---

  def handle_info({:nodeup, node}, state) do
    Logger.info("[Cluster] Node connected: #{node}")
    {:noreply, %{state | connected: MapSet.put(state.connected, node)}}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("[Cluster] Node disconnected: #{node}")
    {:noreply, %{state | connected: MapSet.delete(state.connected, node)}}
  end

  def handle_info(:heartbeat, state) do
    # Reconnect to known hosts if disconnected
    if state.strategy == :epmd do
      Enum.each(state.hosts, fn host ->
        unless host in Node.list() do
          Task.start(fn -> Node.connect(host) end)
        end
      end)
    end

    Process.send_after(self(), :heartbeat, state.interval)
    {:noreply, state}
  end

  @doc "Return a child specification for use in a supervision tree."
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end
end
