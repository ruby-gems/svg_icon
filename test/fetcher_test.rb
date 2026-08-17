# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class FetcherTest < Minitest::Test
  FakeResponse = Struct.new(:code, :body)

  class FakeHttp
    attr_reader :requests

    def initialize(code, body)
      @code = code
      @body = body
      @requests = []
    end

    def get_response(uri)
      @requests << uri
      FakeResponse.new(@code, @body)
    end
  end

  class RaisingHttp
    def initialize(error)
      @error = error
    end

    def get_response(_uri)
      raise @error
    end
  end

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def temp_files
    Dir.glob(File.join(@dir, ".*.tmp*"))
  end

  def test_fetch_downloads_and_writes_file
    body = %({"prefix":"bi","icons":{"search":{"body":"<path/>"}}})
    http = FakeHttp.new("200", body)
    fetcher = SvgIcon::Fetcher.new(http: http)
    destination = File.join(@dir, "bi.json")

    assert fetcher.fetch("bi", destination)
    assert_equal body, File.read(destination)
    assert_equal "https://raw.githubusercontent.com/iconify/icon-sets/master/json/bi.json", http.requests.first.to_s
  end

  def test_fetch_creates_destination_directory
    http = FakeHttp.new("200", %({"icons":{"x":{"body":"1"}}}))
    destination = File.join(@dir, "nested", "bi.json")

    SvgIcon::Fetcher.new(http: http).fetch("bi", destination)

    assert_equal %({"icons":{"x":{"body":"1"}}}), File.read(destination)
  end

  def test_fetch_overwrites_existing_destination
    destination = File.join(@dir, "bi.json")
    first = %({"prefix":"bi","icons":{"search":{"body":"<path/>"}}})

    SvgIcon::Fetcher.new(http: FakeHttp.new("200", first)).fetch("bi", destination)
    SvgIcon::Fetcher.new(http: FakeHttp.new("200", %({"icons":{"x":{"body":"2"}}}))).fetch("bi", destination)

    assert_equal %({"icons":{"x":{"body":"2"}}}), File.read(destination)
  end

  def test_fetch_uses_custom_base_url
    http = FakeHttp.new("200", %({"icons":{"x":{"body":"1"}}}))
    SvgIcon::Fetcher.new(base_url: "https://example.com/sets", http: http).fetch("bi", File.join(@dir, "out.json"))

    assert_equal "https://example.com/sets/bi.json", http.requests.first.to_s
  end

  def test_fetch_raises_on_http_error
    http = FakeHttp.new("404", "Not Found")
    error = assert_raises(SvgIcon::FetchError) do
      SvgIcon::Fetcher.new(http: http).fetch("bi", File.join(@dir, "bi.json"))
    end
    assert_match(/HTTP 404/, error.message)
    assert_match(/not found/, error.message)
  end

  def test_fetch_raises_on_invalid_json
    http = FakeHttp.new("200", "not-json")
    error = assert_raises(SvgIcon::FetchError) do
      SvgIcon::Fetcher.new(http: http).fetch("bi", File.join(@dir, "bi.json"))
    end
    assert_match(/invalid JSON/, error.message)
  end

  def test_fetch_raises_when_icons_key_missing
    http = FakeHttp.new("200", %({"prefix":"bi"}))
    error = assert_raises(SvgIcon::FetchError) do
      SvgIcon::Fetcher.new(http: http).fetch("bi", File.join(@dir, "bi.json"))
    end
    assert_match(/must contain an 'icons' object/, error.message)
  end

  def test_failed_fetch_leaves_no_files
    http = FakeHttp.new("404", "Not Found")
    destination = File.join(@dir, "bi.json")

    assert_raises(SvgIcon::FetchError) { SvgIcon::Fetcher.new(http: http).fetch("bi", destination) }

    refute File.exist?(destination)
    assert_empty temp_files
  end

  def test_fetch_rejects_invalid_names
    http = FakeHttp.new("200", %({"icons":{"x":{"body":"1"}}}))
    fetcher = SvgIcon::Fetcher.new(http: http)

    ["../evil", "bad/name", "bad name", "Bad", "bi.json"].each do |name|
      error = assert_raises(SvgIcon::FetchError) do
        fetcher.fetch(name, File.join(@dir, "out.json"))
      end
      assert_match(/Invalid icon set name/, error.message)
    end

    assert_empty http.requests
  end

  def test_fetch_allows_dash_underscore_digit_names
    http = FakeHttp.new("200", %({"icons":{"x":{"body":"1"}}}))
    SvgIcon::Fetcher.new(http: http).fetch("my-set_2", File.join(@dir, "out.json"))

    assert_equal "https://raw.githubusercontent.com/iconify/icon-sets/master/json/my-set_2.json", http.requests.first.to_s
  end

  def test_rename_failure_cleans_up_temp_file
    http = FakeHttp.new("200", %({"icons":{"x":{"body":"1"}}}))
    destination = File.join(@dir, "blocked")
    Dir.mkdir(destination)

    assert_raises(SystemCallError) do
      SvgIcon::Fetcher.new(http: http).fetch("bi", destination)
    end

    assert_empty temp_files
    assert File.directory?(destination)
    assert_empty Dir.glob(File.join(destination, "*"))
  end

  def test_fetch_wraps_network_errors
    [SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError].each do |error_class|
      error = assert_raises(SvgIcon::FetchError) do
        SvgIcon::Fetcher.new(http: RaisingHttp.new(error_class.new("boom"))).fetch("bi", File.join(@dir, "bi.json"))
      end
      assert_match(/Failed to fetch bi/, error.message)
      assert_match(/boom/, error.message)
    end
  end
end