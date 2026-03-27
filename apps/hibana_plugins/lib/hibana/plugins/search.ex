defmodule Hibana.Plugins.Search do
  @moduledoc """
  Meilisearch search plugin for Hibana.

  Provides a full Meilisearch HTTP client and a plug endpoint for searching.

  ## Configuration

      Hibana.Plugins.Search.configure(
        url: "http://localhost:7700",
        api_key: "your-master-key"
      )

  ## As a Plug

      plug Hibana.Plugins.Search, path: "/search"

  This serves GET /search?q=query&index=idx&limit=20

  ## Options

  ### Plug options (passed to `plug`)

  - `:path` - URL path for the search endpoint (default: `"/search"`)

  ### Configuration options (passed to `configure/1`)

  - `:url` - Meilisearch server URL (default: `"http://localhost:7700"`)
  - `:api_key` - API key for Meilisearch authentication (default: `nil`)
  """

  use Hibana.Plugin

  import Plug.Conn

  @default_path "/search"
  @app_key :hibana_search

  # ── Plug callbacks ──

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    search_path = Keyword.get(opts, :path, @default_path)

    if conn.request_path == search_path and conn.method == "GET" do
      serve_search(conn)
    else
      conn
    end
  end

  # ── Configuration ──

  @doc """
  Configure the Meilisearch connection.

  Options:
  - :url - Meilisearch server URL (default "http://localhost:7700")
  - :api_key - API key for authentication
  """
  def configure(opts) do
    url = Keyword.get(opts, :url, "http://localhost:7700")
    api_key = Keyword.get(opts, :api_key, nil)
    Application.put_env(@app_key, :url, url)
    Application.put_env(@app_key, :api_key, api_key)
    :ok
  end

  # ── Search ──

  @doc """
  Search an index.

  Options:
  - :filter - filter expression
  - :sort - list of sort rules
  - :limit - max results (default 20)
  - :offset - result offset (default 0)
  - :facets - list of facet fields
  - :attributes_to_retrieve - list of attributes to return
  - :attributes_to_highlight - list of attributes to highlight
  """
  def search(index, query, opts \\ []) do
    body =
      %{q: query}
      |> maybe_put(:filter, Keyword.get(opts, :filter))
      |> maybe_put(:sort, Keyword.get(opts, :sort))
      |> maybe_put(:limit, Keyword.get(opts, :limit))
      |> maybe_put(:offset, Keyword.get(opts, :offset))
      |> maybe_put(:facets, Keyword.get(opts, :facets))
      |> maybe_put(:attributesToRetrieve, Keyword.get(opts, :attributes_to_retrieve))
      |> maybe_put(:attributesToHighlight, Keyword.get(opts, :attributes_to_highlight))

    post("/indexes/#{index}/search", body)
  end

  # ── Document operations ──

  @doc "Index (add or replace) documents into an index."
  def index(index_name, documents, opts \\ []) do
    primary_key = Keyword.get(opts, :primary_key)

    path =
      if primary_key do
        "/indexes/#{index_name}/documents?primaryKey=#{primary_key}"
      else
        "/indexes/#{index_name}/documents"
      end

    post(path, documents)
  end

  @doc "Update documents in an index (partial update)."
  def update_documents(index_name, documents) do
    request(:put, "/indexes/#{index_name}/documents", documents)
  end

  @doc "Delete a single document by ID."
  def delete_document(index_name, id) do
    request(:delete, "/indexes/#{index_name}/documents/#{id}")
  end

  @doc "Delete all documents in an index."
  def delete_all_documents(index_name) do
    request(:delete, "/indexes/#{index_name}/documents")
  end

  @doc "Get a single document by ID."
  def get_document(index_name, id) do
    get("/indexes/#{index_name}/documents/#{id}")
  end

  # ── Index operations ──

  @doc """
  Create a new index.

  Options:
  - :primary_key - primary key field name
  """
  def create_index(name, opts \\ []) do
    body =
      %{uid: name}
      |> maybe_put(:primaryKey, Keyword.get(opts, :primary_key))

    post("/indexes", body)
  end

  @doc "Delete an index."
  def delete_index(name) do
    request(:delete, "/indexes/#{name}")
  end

  # ── Stats & Health ──

  @doc "Get stats for an index."
  def stats(index_name) do
    get("/indexes/#{index_name}/stats")
  end

  @doc "Check Meilisearch health."
  def health do
    get("/health")
  end

  # ── Settings ──

  @doc """
  Update index settings.

  Settings map can include:
  - searchableAttributes
  - filterableAttributes
  - sortableAttributes
  - displayedAttributes
  - rankingRules
  - stopWords
  - synonyms
  """
  def update_settings(index_name, settings) when is_map(settings) do
    request(:patch, "/indexes/#{index_name}/settings", settings)
  end

  # ── HTTP Client ──

  defp get(path) do
    request(:get, path)
  end

  defp post(path, body) do
    request(:post, path, body)
  end

  defp request(method, path, body \\ nil) do
    url = base_url() <> path
    headers = build_headers()

    encoded_body =
      case body do
        nil -> ""
        data -> Jason.encode!(data)
      end

    result =
      case method do
        :get ->
          :hackney.request(:get, url, headers, "", with_body: true)

        :post ->
          :hackney.request(:post, url, headers, encoded_body, with_body: true)

        :put ->
          :hackney.request(:put, url, headers, encoded_body, with_body: true)

        :patch ->
          :hackney.request(:patch, url, headers, encoded_body, with_body: true)

        :delete ->
          :hackney.request(:delete, url, headers, "", with_body: true)
      end

    case result do
      {:ok, status, _headers, resp_body} when status in 200..299 ->
        case Jason.decode(resp_body) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:ok, resp_body}
        end

      {:ok, status, _headers, resp_body} ->
        case Jason.decode(resp_body) do
          {:ok, decoded} -> {:error, %{status: status, body: decoded}}
          {:error, _} -> {:error, %{status: status, body: resp_body}}
        end

      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  defp base_url do
    Application.get_env(@app_key, :url, "http://localhost:7700")
  end

  defp build_headers do
    headers = [{"content-type", "application/json"}, {"accept", "application/json"}]

    case Application.get_env(@app_key, :api_key) do
      nil -> headers
      key -> [{"authorization", "Bearer #{key}"} | headers]
    end
  end

  # ── Plug search endpoint ──

  defp serve_search(conn) do
    conn = Plug.Conn.fetch_query_params(conn)
    params = conn.query_params

    index_name = Map.get(params, "index", "default")
    query = Map.get(params, "q", "")
    limit = parse_int(Map.get(params, "limit"), 20)
    offset = parse_int(Map.get(params, "offset"), 0)
    filter = Map.get(params, "filter")
    sort = Map.get(params, "sort")

    opts =
      [limit: limit, offset: offset]
      |> maybe_add(:filter, filter)
      |> maybe_add(:sort, if(sort, do: String.split(sort, ","), else: nil))

    case search(index_name, query, opts) do
      {:ok, results} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(results))
        |> halt()

      {:error, error} ->
        require Logger
        Logger.error("[Search] Search failed: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(502, Jason.encode!(%{error: "Search service unavailable"}))
        |> halt()
    end
  end

  # ── Helpers ──

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_int(nil, default), do: default

  defp parse_int(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end
end
