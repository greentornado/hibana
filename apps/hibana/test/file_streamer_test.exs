defmodule Hibana.FileStreamerTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  alias Hibana.FileStreamer

  setup do
    # Create temp directory with test files
    tmp_dir = Path.join(System.tmp_dir!(), "test_files_#{:rand.uniform(10000)}")
    File.mkdir_p!(tmp_dir)

    # Create test file
    test_file = Path.join(tmp_dir, "test.txt")
    File.write!(test_file, "Hello, World!")

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, test_file: test_file}
  end

  describe "send_file/2" do
    test "successfully sends file", %{test_file: test_file} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, test_file)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
      assert get_resp_header(conn, "etag") != []
      assert get_resp_header(conn, "content-length") == ["13"]
    end

    test "returns 404 for non-existent file" do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, "/nonexistent/file.txt")

      assert conn.status == 404
    end

    test "returns 403 for path traversal attempt" do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, "../../../etc/passwd")

      assert conn.status == 403
    end

    test "handles range request", %{test_file: test_file} do
      conn =
        conn(:get, "/download")
        |> put_req_header("range", "bytes=0-4")

      conn = FileStreamer.send_file(conn, test_file)

      assert conn.status == 206
      assert get_resp_header(conn, "content-range") != []
    end

    test "returns 416 for invalid range", %{test_file: test_file} do
      conn =
        conn(:get, "/download")
        |> put_req_header("range", "bytes=100-200")

      conn = FileStreamer.send_file(conn, test_file)

      assert conn.status == 416
    end

    test "generates correct etag", %{test_file: test_file} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, test_file)

      [etag] = get_resp_header(conn, "etag")
      expected_etag = :crypto.hash(:sha256, File.read!(test_file)) |> Base.encode16(case: :lower)
      assert etag == expected_etag
    end
  end

  describe "send_range/3" do
    test "sends specific byte range", %{test_file: test_file} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_range(conn, test_file, 0, 4)

      assert conn.status == 206
    end
  end
end
