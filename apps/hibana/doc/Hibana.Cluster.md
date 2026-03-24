# `Hibana.Cluster`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/cluster.ex#L1)

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

# `broadcast`

Broadcast a message to all subscribers on all nodes

# `call_on`

Call a function on a specific node

# `cast_on`

Cast a function on a specific node (async)

# `child_spec`

Return a child specification for use in a supervision tree.

# `healthy?`

Check if cluster is healthy

# `init`

# `local_broadcast`

Broadcast only to local node subscribers

# `multicall`

Call a function on all nodes and collect results

# `node_count`

Number of connected nodes

# `nodes`

Get all connected nodes

# `start_link`

Start the cluster manager with the given discovery strategy and options.

# `subscribe`

Subscribe current process to a topic

# `unsubscribe`

Unsubscribe current process from a topic

---

*Consult [api-reference.md](api-reference.md) for complete listing*
