# `Hibana.Plugin.Registry`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugin/registry.ex#L1)

Registry for managing plugins at runtime.

## Features

- Register/unregister plugins dynamically
- List all registered plugins
- Get plugin configuration
- Thread-safe via GenServer

## Usage

    # Start the registry
    {:ok, pid} = Hibana.Plugin.Registry.start_link(name: :my_plugins)

    # Register a plugin
    Hibana.Plugin.Registry.register(
      :my_plugins,
      :auth,
      MyApp.AuthPlugin,
      opts: [secret: "secret"]
    )

    # List all plugins
    Hibana.Plugin.Registry.list_plugins(:my_plugins)

    # Get a specific plugin
    Hibana.Plugin.Registry.get_plugin(:my_plugins, :auth)

    # Unregister a plugin
    Hibana.Plugin.Registry.unregister(:my_plugins, :auth)

## Supervision Integration

    children = [
      {Hibana.Plugin.Registry, name: :plugin_registry}
    ]

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_plugin`

Get a registered plugin's module and options by name.

# `init`

# `list_plugins`

List the names of all registered plugins.

# `register`

Register a plugin module under the given name with options.

# `start_link`

Start the plugin registry process.

# `unregister`

Unregister a plugin by name.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
