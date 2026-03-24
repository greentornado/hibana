# `Hibana.Warmup`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/warmup.ex#L1)

Pre-load data on startup with a macro DSL.

## Usage

    defmodule MyApp.Warmup do
      use Hibana.Warmup

      warmup "load config" do
        Application.fetch_env!(:my_app, :config)
      end

      warmup "prime cache" do
        MyApp.Cache.prime()
      end
    end

Then add to your supervision tree:

    children = [
      MyApp.Warmup
    ]

The module runs all warmup tasks sequentially on `start_link/1` and
returns `:ignore` so it acts as a temporary worker.

# `warmup`
*macro* 

Define a warmup task with a name and body.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
