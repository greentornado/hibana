# `Hibana.Application`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/application.ex#L1)

Hibana application supervision tree.

## Supervision Structure

The application starts:

- `Hibana.Plugin.Registry` - Registry for plugins
- `Hibana.Plugin.Supervisor` - DynamicSupervisor for plugins
- `Hibana.Endpoint` - HTTP endpoint

## Usage

Add to your Mix config:

    def application do
      [
        extra_applications: [:logger],
        mod: {Hibana.Application, []}
      ]
    end

## Children

| Child | Type | Description |
|-------|------|-------------|
| Plugin.Registry | Registry | Plugin registration |
| Plugin.Supervisor | DynamicSupervisor | Plugin supervision |
| Endpoint | Worker | HTTP server |

---

*Consult [api-reference.md](api-reference.md) for complete listing*
