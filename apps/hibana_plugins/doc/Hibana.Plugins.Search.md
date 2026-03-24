# `Hibana.Plugins.Search`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/search.ex#L1)

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

# `before_send`

# `configure`

Configure the Meilisearch connection.

Options:
- :url - Meilisearch server URL (default "http://localhost:7700")
- :api_key - API key for authentication

# `create_index`

Create a new index.

Options:
- :primary_key - primary key field name

# `delete_all_documents`

Delete all documents in an index.

# `delete_document`

Delete a single document by ID.

# `delete_index`

Delete an index.

# `get_document`

Get a single document by ID.

# `health`

Check Meilisearch health.

# `index`

Index (add or replace) documents into an index.

# `search`

Search an index.

Options:
- :filter - filter expression
- :sort - list of sort rules
- :limit - max results (default 20)
- :offset - result offset (default 0)
- :facets - list of facet fields
- :attributes_to_retrieve - list of attributes to return
- :attributes_to_highlight - list of attributes to highlight

# `start_link`

# `stats`

Get stats for an index.

# `update_documents`

Update documents in an index (partial update).

# `update_settings`

Update index settings.

Settings map can include:
- searchableAttributes
- filterableAttributes
- sortableAttributes
- displayedAttributes
- rankingRules
- stopWords
- synonyms

---

*Consult [api-reference.md](api-reference.md) for complete listing*
