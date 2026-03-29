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
    test "successfully sends file", %{tmp_dir: tmp_dir, test_file: test_file} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, test_file, base_dir: tmp_dir)

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/octet-stream"]
      assert get_resp_header(conn, "content-length") == ["13"]
    end

    test "returns 403 for non-existent file", %{tmp_dir: tmp_dir} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, "/nonexistent/file.txt", base_dir: tmp_dir)

      assert conn.status == 403
    end

    test "returns 403 for path traversal attempt", %{tmp_dir: tmp_dir} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_file(conn, "../../../etc/passwd", base_dir: tmp_dir)

      assert conn.status == 403
    end

    test "handles range request", %{tmp_dir: tmp_dir, test_file: test_file} do
      conn =
        conn(:get, "/download")
        |> put_req_header("range", "bytes=0-4")

      conn = FileStreamer.send_file(conn, test_file, base_dir: tmp_dir)

      assert conn.status == 206
      assert get_resp_header(conn, "content-range") != []
    end

    test "returns 403 for invalid range", %{tmp_dir: tmp_dir, test_file: test_file} do
      conn =
        conn(:get, "/download")
        |> put_req_header("range", "bytes=100-200")

      conn = FileStreamer.send_file(conn, test_file, base_dir: tmp_dir)

      # FileStreamer returns 403 or 416 depending on implementation
      assert conn.status in [403, 416]
    end
  end

  describe "send_range/3" do
    test "sends specific byte range", %{tmp_dir: tmp_dir, test_file: test_file} do
      conn = conn(:get, "/download")

      conn = FileStreamer.send_range(conn, test_file, 0, 4, base_dir: tmp_dir)

      assert conn.status == 206
    end
  end
end
