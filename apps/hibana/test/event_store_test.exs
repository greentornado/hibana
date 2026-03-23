defmodule Hibana.EventStoreTest do
  use ExUnit.Case, async: false

  alias Hibana.EventStore

  setup do
    name = :"es_test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = EventStore.start_link(name: name)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{store: name, pid: pid}
  end

  test "start_link starts the event store", %{pid: pid} do
    assert Process.alive?(pid)
  end

  test "append and read events for an aggregate", %{store: store} do
    events = [
      %{type: "user_created", data: %{name: "Alice"}},
      %{type: "user_updated", data: %{name: "Bob"}}
    ]

    assert {:ok, stored} = EventStore.append(store, "user-1", events)
    assert length(stored) == 2

    read_events = EventStore.read(store, "user-1")
    assert length(read_events) == 2

    first = hd(read_events)
    assert first.type == "user_created"
    assert first.aggregate_id == "user-1"
    assert first.sequence == 1
    assert %DateTime{} = first.timestamp
  end

  test "read returns empty list for unknown aggregate", %{store: store} do
    assert EventStore.read(store, "nonexistent") == []
  end

  test "events have sequential sequence numbers", %{store: store} do
    EventStore.append(store, "user-1", [%{type: "created"}])
    EventStore.append(store, "user-1", [%{type: "updated"}])
    EventStore.append(store, "user-2", [%{type: "created"}])

    events_1 = EventStore.read(store, "user-1")
    assert Enum.map(events_1, & &1.sequence) == [1, 2]

    events_2 = EventStore.read(store, "user-2")
    assert Enum.map(events_2, & &1.sequence) == [3]
  end

  test "all_events returns all events ordered by sequence", %{store: store} do
    EventStore.append(store, "a", [%{type: "e1"}])
    EventStore.append(store, "b", [%{type: "e2"}])
    EventStore.append(store, "a", [%{type: "e3"}])

    all = EventStore.all_events(store)
    assert length(all) == 3
    assert Enum.map(all, & &1.sequence) == [1, 2, 3]
  end

  test "projections accumulate state from events", %{store: store} do
    EventStore.append(store, "user-1", [%{type: "user_created"}])
    EventStore.append(store, "user-2", [%{type: "user_created"}])

    EventStore.register_projection(store, :user_count, fn
      %{type: "user_created"}, state -> (state || 0) + 1
      _, state -> state || 0
    end)

    # Projection replays existing events
    assert {:ok, 2} = EventStore.projection(store, :user_count)

    # New events update the projection
    EventStore.append(store, "user-3", [%{type: "user_created"}])
    assert {:ok, 3} = EventStore.projection(store, :user_count)
  end

  test "projection returns error for unknown projection", %{store: store} do
    assert {:error, :not_found} = EventStore.projection(store, :nonexistent)
  end

  test "subscribe receives events matching pattern", %{store: store} do
    EventStore.subscribe(store, "user_*")

    EventStore.append(store, "user-1", [%{type: "user_created", data: %{name: "Alice"}}])

    assert_receive {:event, event}
    assert event.type == "user_created"
  end

  test "subscribe does not receive non-matching events", %{store: store} do
    EventStore.subscribe(store, "order_*")

    EventStore.append(store, "user-1", [%{type: "user_created"}])

    refute_receive {:event, _}, 50
  end

  test "unsubscribe stops receiving events", %{store: store} do
    EventStore.subscribe(store, "user_*")
    EventStore.unsubscribe(store)

    EventStore.append(store, "user-1", [%{type: "user_created"}])

    refute_receive {:event, _}, 50
  end
end
