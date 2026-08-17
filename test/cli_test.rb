# frozen_string_literal: true

require "test_helper"

class CliTest < Minitest::Test
  FakeFetcher = Struct.new(:name, :destination) do
    def fetch(name, destination)
      self.name = name
      self.destination = destination
    end
  end

  def with_stubbed_fetcher(stub)
    original = SvgIcon::Fetcher.method(:new)
    SvgIcon::Fetcher.singleton_class.send(:define_method, :new) do |*args, &blk|
      stub.respond_to?(:call) ? stub.call(*args, &blk) : stub
    end
    yield
  ensure
    SvgIcon::Fetcher.singleton_class.send(:define_method, :new, &original)
  end

  def test_fetch_downloads_into_icons_path
    fake = FakeFetcher.new
    with_stubbed_fetcher(fake) do
      out, = capture_io { SvgIcon::CLI.run(["fetch", "bi"]) }
      assert_equal "bi", fake.name
      assert_equal File.join(SvgIcon.configuration.icons_path, "bi.json"), fake.destination
      assert_includes out, "Saved to"
    end
  end

  def test_fetch_without_name_exits_with_usage
    error = assert_raises(SystemExit) do
      capture_io { SvgIcon::CLI.run(["fetch"]) }
    end
    assert_equal 1, error.status
  end

  def test_fetch_with_invalid_name_exits
    error = assert_raises(SystemExit) do
      capture_io { SvgIcon::CLI.run(["fetch", "../evil"]) }
    end
    assert_equal 1, error.status
  end

  def test_fetch_with_extra_arguments_exits
    error = assert_raises(SystemExit) do
      capture_io { SvgIcon::CLI.run(["fetch", "bi", "extra"]) }
    end
    assert_equal 1, error.status
  end

  def test_fetch_propagates_fetch_error
    with_stubbed_fetcher(-> { raise SvgIcon::FetchError, "boom" }) do
      _, err = capture_io do
        error = assert_raises(SystemExit) { SvgIcon::CLI.run(["fetch", "bi"]) }
        assert_equal 1, error.status
      end
      assert_includes err, "boom"
    end
  end

  def test_fetch_handles_unexpected_errors
    with_stubbed_fetcher(-> { raise RuntimeError, "kaboom" }) do
      _, err = capture_io do
        error = assert_raises(SystemExit) { SvgIcon::CLI.run(["fetch", "bi"]) }
        assert_equal 1, error.status
      end
      assert_includes err, "Error:"
      assert_includes err, "kaboom"
    end
  end

  def test_unknown_command_exits
    error = assert_raises(SystemExit) do
      capture_io { SvgIcon::CLI.run(["frobnicate"]) }
    end
    assert_equal 1, error.status
  end

  def test_help_prints_usage_without_error
    out, = capture_io { SvgIcon::CLI.run(["help"]) }
    assert_includes out, "Usage:"
  end
end
