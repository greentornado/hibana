defmodule Hibana.Plugins.OTPCache do
  @moduledoc """
  OTP-based in-memory cache plugin.

  This module delegates to `Hibana.OTPCache`.
  See `Hibana.OTPCache` for full documentation.

  ## Usage

      # Start the cache
      Hibana.Plugins.OTPCache.start_link(name: :my_cache)

      # Set/Get values
      Hibana.Plugins.OTPCache.put(:my_cache, "key", "value", ttl: 60_000)
      Hibana.Plugins.OTPCache.get(:my_cache, "key")

  ## Options

  Options are passed through to `Hibana.OTPCache.start_link/1`. See `Hibana.OTPCache` for the full list of supported options.
  """

  defdelegate start_link(opts \\ []), to: Hibana.OTPCache

  defdelegate put(server \\ Hibana.OTPCache, key, value, opts \\ []),
    to: Hibana.OTPCache

  defdelegate get(server \\ Hibana.OTPCache, key), to: Hibana.OTPCache

  defdelegate get_or_compute(server \\ Hibana.OTPCache, key, compute_fn, opts \\ []),
    to: Hibana.OTPCache

  defdelegate delete(server \\ Hibana.OTPCache, key), to: Hibana.OTPCache
  defdelegate exists?(server \\ Hibana.OTPCache, key), to: Hibana.OTPCache
  defdelegate clear(server \\ Hibana.OTPCache), to: Hibana.OTPCache
  defdelegate stats(server \\ Hibana.OTPCache), to: Hibana.OTPCache
end
