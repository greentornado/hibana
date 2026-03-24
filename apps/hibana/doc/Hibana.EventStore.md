# `Hibana.EventStore`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/event_store.ex#L1)

Event sourcing with GenServer, ETS storage, projections, and subscriptions.

## Usage

    {:ok, store} = Hibana.EventStore.start_link(name: :my_store)

    Hibana.EventStore.append(store, "user-1", [
      %{type: "user_created", data: %{name: "Alice"}},
      %{type: "user_updated", data: %{name: "Bob"}}
    ])

    Hibana.EventStore.read(store, "user-1")

    Hibana.EventStore.subscribe(store, "user_*")

    Hibana.EventStore.register_projection(store, :user_count, fn
      %{type: "user_created"}, state -> (state || 0) + 1
      _, state -> state || 0
    end)

    Hibana.EventStore.projection(store, :user_count)

# `all_events`

Get all events in the store, ordered by sequence number.

# `append`

Append events to an aggregate stream.
Events are maps with at least a `:type` key.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `projection`

Get the current state of a projection.

# `read`

Read all events for an aggregate.

# `register_projection`

Register a projection with a reducer function.
The reducer receives `(event, current_state)` and returns new state.
Automatically replays all existing events.

# `start_link`

Start the event store.

# `subscribe`

Subscribe to events matching a pattern.
Pattern supports wildcards with `*`.
The calling process will receive `{:event, event}` messages.

# `unsubscribe`

Unsubscribe from events.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
