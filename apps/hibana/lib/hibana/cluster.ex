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

  ## Security Warning

  RPC functions (`call_on/5`, `cast_on/4`, `multicall/4`) allow remote code execution.
  By default, only safe modules are whitelisted. Configure `rpc_whitelist` to customize:

      {Hibana.Cluster, 
        strategy: :epmd, 
        hosts: [:"app@node1"],
        rpc_whitelist: [
          {MyApp.Module, :my_function},
          {Kernel, :node}
        ]
      }

  Always use Erlang distribution cookie authentication in production:

      # vm.args or environment
      -setcookie YOUR_SECRET_COOKIE

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

  - `:epmd` — Connect to known hosts via Erlang distribution (requires pre-configured host list)
  - `:dns` — Discover nodes via DNS A records (automatically finds nodes by domain name)
  - `:gossip` — UDP gossip protocol for automatic discovery (broadcast-based, no central registry)

  ### EPMD Strategy

  Connects to explicitly configured hosts:

      {Hibana.Cluster, strategy: :epmd, hosts: [:"myapp@host1", :"myapp@host2"]}

  ### DNS Strategy

  Discovers nodes by querying DNS:

      {Hibana.Cluster, strategy: :dns, query: "myapp.local", app_name: "myapp"}

  Options:
  - `:query` - DNS domain to query (required)
  - `:app_name` - Application name for constructing node names (defaults to current node's app name)

  ### Gossip Strategy

  Uses UDP broadcast for automatic discovery (good for Docker/Kubernetes):

      {Hibana.Cluster, strategy: :gossip, port: 45892}

  Options:
  - `:port` - UDP port for gossip (default: 45892, falls back to ephemeral if unavailable)

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
      - `:rpc_whitelist` - List of allowed `{module, function}` tuples for RPC calls (default: see `@default_whitelist`)

  ## Security

  RPC functions are restricted to a whitelist of safe modules/functions by default.
  The default whitelist includes:
  - `{Kernel, :node}`, `{Kernel, :self}`, `{Kernel, :+}`, etc. (safe Kernel functions)
  - `{Hibana.Cluster, :local_broadcast}` (for PubSub)

  Customize with `:rpc_whitelist` option. Set to `:all` to disable restrictions (NOT RECOMMENDED).

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      # Fully supported
      Hibana.Cluster.start_link(strategy: :epmd, hosts: [:"app@node1", :"app@node2"])
      
      # With custom RPC whitelist
      Hibana.Cluster.start_link(
        strategy: :epmd,
        hosts: [:"app@node1"],
        rpc_whitelist: [
          {MyApp.Stats, :get_metrics},
          {Kernel, :node}
        ]
      )
      ```
  """
  def start_link(opts \\ []) do
    # Validate strategy before starting GenServer so errors can be caught
    strategy = Keyword.get(opts, :strategy, :epmd)

    case strategy do
      :epmd ->
        :ok

      # Falls back to epmd with warning
      :dns ->
        :ok

      # Falls back to epmd with warning
      :gossip ->
        :ok

      other ->
        raise ArgumentError,
              "Unknown cluster strategy: #{inspect(other)}. Supported: :epmd (default). :dns and :gossip fall back to epmd with warnings."
    end

    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Default whitelist of safe RPC functions
  @default_whitelist [
    # Kernel functions that are safe
    {Kernel, :node},
    {Kernel, :self},
    {Kernel, :length},
    {Kernel, :+},
    {Kernel, :-},
    {Kernel, :*},
    {Kernel, :div},
    {Kernel, :rem},
    {Kernel, :inspect},
    {Kernel, :to_string},
    # System info functions
    {:erlang, :system_info},
    {:erlang, :memory},
    {:erlang, :statistics},
    # Hibana functions for PubSub
    {__MODULE__, :local_broadcast},
    {Hibana.Cluster, :local_broadcast}
  ]

  def init(opts) do
    # Registry is started by Hibana.Application supervisor before Cluster
    # It uses: {Registry, keys: :duplicate, name: Hibana.Cluster.PubSub}

    # Verify registry is available
    unless Process.whereis(@registry) do
      raise "Cluster Registry #{@registry} not started. Ensure Hibana.Cluster.Registry is started before Hibana.Cluster in the supervision tree."
    end

    strategy = Keyword.get(opts, :strategy, :epmd)
    hosts = Keyword.get(opts, :hosts, [])
    interval = Keyword.get(opts, :heartbeat_interval, 5_000)

    # RPC whitelist - default to safe list, :all means no restrictions
    rpc_whitelist = Keyword.get(opts, :rpc_whitelist, @default_whitelist)

    # Validate whitelist format
    validated_whitelist =
      case rpc_whitelist do
        :all ->
          :all

        list when is_list(list) ->
          Enum.each(list, fn
            {mod, fun} when is_atom(mod) and is_atom(fun) ->
              :ok

            other ->
              Logger.warning(
                "[Cluster] Invalid rpc_whitelist entry: #{inspect(other)}. Expected {module, function}."
              )
          end)

          list

        other ->
          Logger.warning(
            "[Cluster] Invalid rpc_whitelist: #{inspect(other)}. Using default whitelist."
          )

          @default_whitelist
      end

    # Validate and warn about unimplemented strategies
    state =
      case strategy do
        :epmd ->
          %{
            strategy: strategy,
            hosts: hosts,
            interval: interval,
            connected: MapSet.new(),
            rpc_whitelist: validated_whitelist,
            # Reconnect backoff tracking
            reconnect_attempts: %{},
            max_reconnect_attempts: Keyword.get(opts, :max_reconnect_attempts, 10),
            base_interval: interval,
            max_interval: Keyword.get(opts, :max_reconnect_interval, 300_000)
          }

        :dns ->
          query = Keyword.get(opts, :query)
          app_name = Keyword.get(opts, :app_name, app_name_from_node())
          port = Keyword.get(opts, :port, 0)

          unless query do
            raise ArgumentError, "DNS strategy requires :query option (e.g., 'myapp.local')"
          end

          %{
            strategy: :dns,
            query: query,
            app_name: app_name,
            port: port,
            # Will be populated via DNS discovery
            hosts: [],
            interval: interval,
            connected: MapSet.new(),
            rpc_whitelist: validated_whitelist,
            reconnect_attempts: %{},
            max_reconnect_attempts: Keyword.get(opts, :max_reconnect_attempts, 10),
            base_interval: interval,
            max_interval: Keyword.get(opts, :max_reconnect_interval, 300_000)
          }

        :gossip ->
          port = Keyword.get(opts, :port, 45892)

          %{
            strategy: :gossip,
            gossip_port: port,
            # Will be populated via gossip
            hosts: [],
            interval: interval,
            connected: MapSet.new(),
            rpc_whitelist: validated_whitelist,
            reconnect_attempts: %{},
            max_reconnect_attempts: Keyword.get(opts, :max_reconnect_attempts, 10),
            base_interval: interval,
            max_interval: Keyword.get(opts, :max_reconnect_interval, 300_000),
            # Gossip-specific state
            gossip_socket: nil,
            known_nodes: MapSet.new()
          }

        other ->
          raise ArgumentError,
                "Unknown cluster strategy: #{inspect(other)}. Supported: :epmd (default). :dns and :gossip fall back to epmd with warnings."
      end

    # Connect to known hosts (for epmd strategy) or start discovery
    case strategy do
      :epmd when hosts != [] ->
        Enum.each(hosts, &Node.connect/1)

      :dns ->
        # Initial DNS discovery
        discovered = discover_nodes_via_dns(state.query, state.app_name)
        Enum.each(discovered, &Node.connect/1)

      :gossip ->
        # Start gossip socket
        {:ok, socket} = start_gossip_socket(state.gossip_port)

        new_state = %{
          state
          | gossip_socket: socket,
            known_nodes: MapSet.new(discover_nodes_via_gossip(socket))
        }

        Enum.each(new_state.known_nodes, &Node.connect/1)

      _ ->
        :ok
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
    case Registry.register(@registry, topic, []) do
      {:ok, _} -> :ok
      {:error, {:already_registered, _}} -> :ok
    end
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
  Publishes a message to all subscribers on all connected nodes.

  Alias for `broadcast/2`.
  """
  def publish(topic, message) do
    broadcast(topic, message)
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

  ## Security

  This function is restricted by the RPC whitelist configured at startup.
  Only whitelisted `{module, function}` pairs can be called remotely.
  Attempting to call non-whitelisted functions will return `{:error, :rpc_not_allowed}`.

  ## Parameters

    - `node` - The target node atom
    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments
    - `timeout` - Timeout in milliseconds (default: `5_000`)

  ## Returns

  The return value of the remote function call, or `{:error, :rpc_not_allowed}` if not whitelisted.

  ## Examples

      ```elixir
      Hibana.Cluster.call_on(:"app@node2", Kernel, :node, [])
      # Returns node name of remote node
      ```
  """
  def call_on(node, mod, fun, args, timeout \\ 5_000) do
    if rpc_allowed?(mod, fun) do
      :rpc.call(node, mod, fun, args, timeout)
    else
      Logger.warning("[Cluster] RPC call to #{inspect(mod)}.#{fun} blocked - not in whitelist")
      {:error, :rpc_not_allowed}
    end
  end

  @doc """
  Casts (fires and forgets) a function call on a specific remote node.

  ## Security

  This function is restricted by the RPC whitelist configured at startup.
  Only whitelisted `{module, function}` pairs can be called remotely.

  ## Parameters

    - `node` - The target node atom
    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments

  ## Returns

  `:true` if allowed (always, since it's asynchronous), or `{:error, :rpc_not_allowed}` if not whitelisted.
  """
  def cast_on(node, mod, fun, args) do
    if rpc_allowed?(mod, fun) do
      :rpc.cast(node, mod, fun, args)
    else
      Logger.warning("[Cluster] RPC cast to #{inspect(mod)}.#{fun} blocked - not in whitelist")
      {:error, :rpc_not_allowed}
    end
  end

  @doc """
  Calls a function on all connected nodes and collects the results.

  ## Security

  This function is restricted by the RPC whitelist configured at startup.
  Only whitelisted `{module, function}` pairs can be called remotely.
  Non-whitelisted calls will return `{:error, :rpc_not_allowed}` for all nodes.

  ## Parameters

    - `mod` - The module to call
    - `fun` - The function name atom
    - `args` - List of arguments
    - `timeout` - Timeout in milliseconds (default: `5_000`)

  ## Returns

  A tuple `{results, bad_nodes}` where `results` is a list of return values
  and `bad_nodes` is a list of nodes that failed to respond.
  Returns `{[{:error, :rpc_not_allowed}], nodes()}` if not whitelisted.

  ## Examples

      ```elixir
      {results, bad_nodes} = Hibana.Cluster.multicall(Kernel, :node, [])
      ```
  """
  def multicall(mod, fun, args, timeout \\ 5_000) do
    if rpc_allowed?(mod, fun) do
      :rpc.multicall(nodes(), mod, fun, args, timeout)
    else
      Logger.warning(
        "[Cluster] RPC multicall to #{inspect(mod)}.#{fun} blocked - not in whitelist"
      )

      {Enum.map(nodes(), fn _ -> {:error, :rpc_not_allowed} end), nodes()}
    end
  end

  @doc """
  Checks if an RPC call to `{mod, fun}` is allowed based on the whitelist.

  ## Parameters

    - `mod` - Module atom
    - `fun` - Function atom

  ## Returns

  `true` if allowed, `false` otherwise.
  """
  def rpc_allowed?(mod, fun) do
    case GenServer.call(__MODULE__, :get_whitelist) do
      :all -> true
      whitelist -> {mod, fun} in whitelist
    end
  end

  @doc """
  Returns the current RPC whitelist configuration.

  ## Returns

    - `:all` if all RPC calls are allowed (not recommended)
    - List of `{module, function}` tuples if restricted
  """
  def get_rpc_whitelist do
    GenServer.call(__MODULE__, :get_whitelist)
  end

  # --- GenServer callbacks ---

  def handle_call(:get_whitelist, _from, state) do
    {:reply, state.rpc_whitelist, state}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("[Cluster] Node connected: #{node}")
    # Reset reconnect attempts for this node
    attempts = Map.delete(state.reconnect_attempts, node)

    {:noreply,
     %{state | connected: MapSet.put(state.connected, node), reconnect_attempts: attempts}}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.info("[Cluster] Node disconnected: #{node}")
    # Initialize or increment reconnect attempts
    attempts = Map.put_new(state.reconnect_attempts, node, 0)

    {:noreply,
     %{state | connected: MapSet.delete(state.connected, node), reconnect_attempts: attempts}}
  end

  def handle_info(:heartbeat, state) do
    # Handle different strategies
    new_state =
      case state.strategy do
        :epmd ->
          # Reconnect to known hosts with exponential backoff
          Enum.reduce(state.hosts, state, fn host, acc_state ->
            if host in Node.list() do
              %{acc_state | reconnect_attempts: Map.delete(acc_state.reconnect_attempts, host)}
            else
              try_reconnect_with_backoff(host, acc_state)
            end
          end)

        :dns ->
          # Periodic DNS rediscovery
          discovered = discover_nodes_via_dns(state.query, state.app_name)
          current_nodes = Node.list()

          # Connect to newly discovered nodes
          new_connections =
            Enum.reduce(discovered, state, fn node, acc_state ->
              if node in current_nodes do
                acc_state
              else
                case Node.connect(node) do
                  true ->
                    Logger.info("[Cluster] DNS discovery: connected to #{node}")

                    %{
                      acc_state
                      | reconnect_attempts: Map.delete(acc_state.reconnect_attempts, node)
                    }

                  _ ->
                    try_reconnect_with_backoff(node, acc_state)
                end
              end
            end)

          # Update hosts list with discovered nodes
          %{new_connections | hosts: discovered}

        :gossip ->
          # Receive gossip messages and update known nodes
          new_known = receive_gossip_messages(state.gossip_socket, state.known_nodes)

          # Try to connect to new nodes from gossip
          Enum.reduce(new_known, state, fn node, acc_state ->
            if node in Node.list() or node == Node.self() do
              acc_state
            else
              case Node.connect(node) do
                true ->
                  Logger.info("[Cluster] Gossip discovery: connected to #{node}")

                  %{
                    acc_state
                    | reconnect_attempts: Map.delete(acc_state.reconnect_attempts, node)
                  }

                _ ->
                  try_reconnect_with_backoff(node, acc_state)
              end
            end
          end)
          |> Map.put(:known_nodes, new_known)

        _ ->
          state
      end

    # Calculate next heartbeat interval
    next_interval = calculate_heartbeat_interval(new_state)

    Process.send_after(self(), :heartbeat, next_interval)
    {:noreply, %{new_state | interval: next_interval}}
  end

  defp try_reconnect_with_backoff(host, state) do
    attempts = Map.get(state.reconnect_attempts, host, 0)

    if attempts >= state.max_reconnect_attempts do
      # Max attempts reached, stop trying and log once
      if attempts == state.max_reconnect_attempts do
        Logger.error(
          "[Cluster] Max reconnect attempts (#{state.max_reconnect_attempts}) reached for #{host}. Giving up."
        )
      end

      # Mark as exceeded but don't remove to prevent repeated logging
      %{
        state
        | reconnect_attempts:
            Map.put(state.reconnect_attempts, host, state.max_reconnect_attempts + 1)
      }
    else
      # Try to connect
      case Node.connect(host) do
        true ->
          Logger.info("[Cluster] Successfully reconnected to #{host}")
          %{state | reconnect_attempts: Map.delete(state.reconnect_attempts, host)}

        _ ->
          # Failed, increment attempts
          new_attempts = attempts + 1

          # Only log warning every few attempts to avoid spam
          if rem(new_attempts, 3) == 1 or new_attempts >= state.max_reconnect_attempts - 2 do
            Logger.warning(
              "[Cluster] Failed to connect to #{host} (attempt #{new_attempts}/#{state.max_reconnect_attempts})"
            )
          end

          %{state | reconnect_attempts: Map.put(state.reconnect_attempts, host, new_attempts)}
      end
    end
  end

  defp calculate_heartbeat_interval(state) do
    # If there are hosts with pending reconnects, use backoff interval
    # Otherwise use base interval

    pending_attempts =
      state.reconnect_attempts
      |> Enum.filter(fn {_, count} -> count > 0 and count <= state.max_reconnect_attempts end)
      |> Enum.map(fn {_, count} -> count end)

    if pending_attempts == [] do
      # No pending reconnects, use base interval
      state.base_interval
    else
      # Use exponential backoff based on max attempts
      max_attempt = Enum.max(pending_attempts, fn -> 0 end)

      # Exponential backoff: base * 2^attempts, capped at max_interval
      backoff = (state.base_interval * :math.pow(2, max_attempt)) |> round()
      min(backoff, state.max_interval)
    end
  end

  # --- DNS Discovery ---

  @doc """
  Discovers cluster nodes via DNS lookup.

  Queries DNS for the given domain and constructs node names using the
  application name and short hostnames from DNS records.

  ## Parameters

    - `query` - DNS domain to query (e.g., "myapp.local")
    - `app_name` - The application name for constructing node names (e.g., "myapp")

  ## Returns

  List of node atoms like `[:"myapp@host1", :"myapp@host2"]`
  """
  def discover_nodes_via_dns(query, app_name) do
    try do
      # Use Erlang's inet_res for DNS lookup
      case :inet_res.gethostbyname(to_charlist(query)) do
        {:ok, {:hostent, _name, _aliases, :inet, _addrtype, addresses}} ->
          # Convert IP addresses to hostnames and construct node names
          nodes =
            Enum.map(addresses, fn ip ->
              # Try to reverse lookup the IP to get hostname
              case :inet_res.gethostbyaddr(ip) do
                {:ok, {:hostent, hostname, _aliases, _addrtype, _addresses}} ->
                  hostname_str = to_string(hostname)
                  # Remove domain part if present
                  shortname = hostname_str |> String.split(".") |> List.first()
                  :"#{app_name}@#{shortname}"

                _ ->
                  # Fallback to IP address
                  ip_str = :inet.ntoa(ip) |> to_string()
                  :"#{app_name}@#{ip_str}"
              end
            end)
            |> Enum.reject(fn node -> node == Node.self() end)

          Logger.debug("[Cluster] DNS discovery found #{length(nodes)} nodes: #{inspect(nodes)}")
          nodes

        {:error, reason} ->
          Logger.warning("[Cluster] DNS lookup failed for #{query}: #{inspect(reason)}")
          []
      end
    rescue
      e ->
        Logger.error("[Cluster] DNS discovery error: #{inspect(e)}")
        []
    end
  end

  @doc """
  Extracts the app name from the current node name.

  ## Examples

      # For node :"myapp@host1", returns "myapp"
      app_name_from_node()
  """
  def app_name_from_node do
    Node.self() |> to_string() |> String.split("@") |> List.first()
  end

  # --- Gossip Discovery ---

  @doc """
  Starts the UDP gossip socket for node discovery.

  ## Parameters

    - `port` - UDP port to listen on (default: 45892)

  ## Returns

    - `{:ok, socket}` on success
    - `{:error, reason}` on failure
  """
  def start_gossip_socket(port \\ 45892) do
    try do
      # Open UDP socket
      case :gen_udp.open(port, [:binary, active: true, reuseaddr: true, broadcast: true]) do
        {:ok, socket} ->
          Logger.info("[Cluster] Gossip socket started on port #{port}")
          {:ok, socket}

        {:error, :eaddrinuse} ->
          # Port already in use, try ephemeral port
          case :gen_udp.open(0, [:binary, active: true, reuseaddr: true, broadcast: true]) do
            {:ok, socket} ->
              {:ok, port_num} = :inet.port(socket)
              Logger.info("[Cluster] Gossip socket started on ephemeral port #{port_num}")
              {:ok, socket}

            error ->
              Logger.error("[Cluster] Failed to start gossip socket: #{inspect(error)}")
              error
          end

        error ->
          Logger.error("[Cluster] Failed to start gossip socket: #{inspect(error)}")
          error
      end
    rescue
      e ->
        Logger.error("[Cluster] Gossip socket start error: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Discovers nodes via gossip protocol.

  Sends a broadcast discovery message and collects responses.

  ## Parameters

    - `socket` - UDP socket from start_gossip_socket/1

  ## Returns

  List of discovered node atoms
  """
  def discover_nodes_via_gossip(socket) do
    try do
      # Broadcast our presence
      message = "DISCOVER:#{Node.self()}"
      :gen_udp.send(socket, {255, 255, 255, 255}, 45892, message)

      # Wait briefly for responses
      receive_gossip_messages(socket, MapSet.new(), 500)
    rescue
      e ->
        Logger.error("[Cluster] Gossip discovery error: #{inspect(e)}")
        MapSet.new()
    end
  end

  defp receive_gossip_messages(socket, known_nodes \\ MapSet.new(), timeout \\ 1000) do
    receive do
      {:udp, ^socket, _ip, _port, data} ->
        case parse_gossip_message(data) do
          {:ok, node} ->
            if node != Node.self() do
              receive_gossip_messages(socket, MapSet.put(known_nodes, node), timeout)
            else
              receive_gossip_messages(socket, known_nodes, timeout)
            end

          :error ->
            receive_gossip_messages(socket, known_nodes, timeout)
        end
    after
      timeout ->
        known_nodes
    end
  end

  defp parse_gossip_message(data) do
    case String.split(to_string(data), ":", parts: 2) do
      ["DISCOVER", node_str] ->
        try do
          {:ok, String.to_atom(node_str)}
        rescue
          _ -> :error
        end

      ["ALIVE", node_str] ->
        try do
          {:ok, String.to_atom(node_str)}
        rescue
          _ -> :error
        end

      _ ->
        :error
    end
  end

  @doc """
  Broadcasts gossip message to announce node presence.
  """
  def announce_presence(socket) do
    try do
      message = "ALIVE:#{Node.self()}"
      :gen_udp.send(socket, {255, 255, 255, 255}, 45892, message)
    rescue
      _ -> :ok
    end
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
