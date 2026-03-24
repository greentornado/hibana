# `Hibana.Plugins.Upload`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/upload.ex#L1)

File upload handling plugin.

## Features

- Configurable maximum file size
- MIME type validation
- Custom upload directory
- Ready-to-use upload endpoint

## Usage

    plug Hibana.Plugins.Upload,
      max_file_size: 10_000_000,
      allowed_types: ["image/jpeg", "image/png", "application/pdf"],
      upload_dir: "priv/uploads"

## Options

- `:max_file_size` - Maximum file size in bytes (default: `5_000_000` = 5MB)
- `:allowed_types` - List of allowed MIME types (default: `[]` = all)
- `:upload_dir` - Directory to save uploads (default: `"priv/uploads"`)

## Upload Endpoint

POST /upload

Returns JSON confirmation that endpoint is ready.
Extend this plugin for full multipart file handling.

## Validation

The plugin validates:

- File size against `:max_file_size`
- MIME type against `:allowed_types` (if specified)

## File Storage

Uploaded files are saved to `:upload_dir` with generated filenames:

    priv/uploads/uuid-filename.ext

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
