# svg_icon fetch CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `svg_icon fetch <name>` CLI that downloads icon sets from iconify/icon-sets into the project, usable as independent icon sets via config.

**Architecture:** New `SvgIcon::Fetcher` class (net/http, injectable for tests) handles download/validate/atomic-write. New `SvgIcon::CLI` class + `exe/svg_icon` thin wrapper dispatch `fetch`. Configuration gains `icons_path`; `file_data` resolution order becomes external `icons_path/<icon>.json` → bundled `lib/data/<icon>.json` → raise.

**Tech Stack:** Ruby, minitest, net/http (stdlib), multi_json, OptionParser-free manual dispatch (tiny surface).

**Spec:** `docs/superpowers/specs/2026-08-18-svg-icon-fetch-design.md`

---

### Task 1: `icons_path` config + external-first data resolution

**Files:**
- Modify: `lib/svg_icon/configuration.rb`
- Modify: `lib/svg_icon.rb`
- Test: `test/svg_icon_test.rb`

- [ ] **Step 1: Write the failing tests**

Append to `test/svg_icon_test.rb`:

```ruby
def test_default_icons_path_points_to_project_config_dir
  assert_equal File.join(Dir.pwd, "config", "svg_icons"), SvgIcon.configuration.icons_path
end

def test_icons_loads_from_icons_path_when_present
  Dir.mktmpdir do |dir|
    File.write(File.join(dir, "custom.json"), %({"prefix":"custom","icons":{"x":{"body":"1"}}}))
    SvgIcon.configure { |config| config.icon = "custom"; config.icons_path = dir }
    assert_equal "custom", SvgIcon.icons["prefix"]
  end
end

def test_icons_falls_back_to_bundled_data
  Dir.mktmpdir do |dir|
    SvgIcon.configure { |config| config.icon = "lucide"; config.icons_path = dir }
    assert_equal "lucide", SvgIcon.icons["prefix"]
  end
end

def test_icons_raises_when_file_missing_everywhere
  Dir.mktmpdir do |dir|
    SvgIcon.configure { |config| config.icon = "nonexistent"; config.icons_path = dir }
    error = assert_raises(SvgIcon::Error) { SvgIcon.icons }
    assert_match(/Icon data file not found/, error.message)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib -Itest test/svg_icon_test.rb`
Expected: `test_default_icons_path...` FAILS with `NoMethodError: undefined method 'icons_path'`; the other three fail with `Icon data file not found: .../lib/data/custom.json` (external dir never consulted).

- [ ] **Step 3: Add `icons_path` to Configuration**

In `lib/svg_icon/configuration.rb`, change the class to:

```ruby
class Configuration
  DEFAULT_ICON = "lucide"

  attr_accessor :icon
  attr_accessor :default_class
  attr_accessor :extra_icons_path
  attr_accessor :icons_path

  def initialize
    @icon = DEFAULT_ICON
    @icons_path = File.join(Dir.pwd, "config", "svg_icons")
  end
end
```

- [ ] **Step 4: External-first resolution in `lib/svg_icon.rb`**

Replace the `data_path` and `file_data` methods (currently `data_path` builds `File.join(__dir__, "data", ...)` and `file_data` memoizes by path) with:

```ruby
def file_data
  @file_data ||= {}
  @file_data[icon] ||= begin
    path = resolve_icon_path
    raise Error, "Icon data file not found: #{path}" unless File.exist?(path)

    File.read(path)
  end
end

def resolve_icon_path
  external = File.join(configuration.icons_path, "#{icon}.json")
  return external if File.exist?(external)

  File.join(__dir__, "data", "#{icon}.json")
end
```

Then in `merge_extra_icons` (same file), replace `#{data_path}` with `#{resolve_icon_path}` in the error message. Delete the now-unused `data_path` method.

- [ ] **Step 5: Run full test suite**

Run: `bundle exec rake test`
Expected: all 26 tests pass (22 existing + 4 new).

- [ ] **Step 6: Commit**

```bash
git add lib/svg_icon.rb lib/svg_icon/configuration.rb test/svg_icon_test.rb
git commit -m "feat: support external icon sets via icons_path config"
```

---

### Task 2: `SvgIcon::Fetcher`

**Files:**
- Create: `lib/svg_icon/fetcher.rb`
- Create: `test/fetcher_test.rb`
- Modify: `lib/svg_icon.rb` (require fetcher)

- [ ] **Step 1: Write the failing tests**

Create `test/fetcher_test.rb`:

```ruby
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

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
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
    assert_empty Dir.glob(File.join(@dir, "*.tmp*"))
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib -Itest test/fetcher_test.rb`
Expected: all FAIL with `NameError: uninitialized constant SvgIcon::Fetcher`.

- [ ] **Step 3: Implement Fetcher**

Create `lib/svg_icon/fetcher.rb`:

```ruby
# frozen_string_literal: true

require "net/http"
require "tempfile"

module SvgIcon
  class FetchError < Error; end

  class Fetcher
    DEFAULT_BASE_URL = "https://raw.githubusercontent.com/iconify/icon-sets/master/json"

    def initialize(base_url: DEFAULT_BASE_URL, http: Net::HTTP)
      @base_url = base_url
      @http = http
    end

    def fetch(name, destination)
      response = @http.get_response(uri_for(name))
      raise FetchError, "Failed to fetch #{name}: HTTP #{response.code}#{not_found_hint(response.code)}" unless response.code == "200"

      parse(response.body, name)
      write(response.body, destination)
      true
    end

    private

    def uri_for(name)
      URI.join("#{@base_url}/", "#{name}.json")
    end

    def not_found_hint(code)
      code == "404" ? " (icon set not found)" : ""
    end

    def parse(body, name)
      data = MultiJson.load(body)
      return if data.is_a?(Hash) && data["icons"].is_a?(Hash)

      raise FetchError, "Invalid icon set '#{name}': JSON must contain an 'icons' object"
    rescue MultiJson::ParseError => e
      raise FetchError, "Invalid icon set '#{name}': invalid JSON (#{e.message})"
    end

    def write(body, destination)
      dir = File.dirname(destination)
      FileUtils.mkdir_p(dir)
      temp = Tempfile.new([".#{File.basename(destination)}", ".tmp"], dir)
      begin
        temp.write(body)
        temp.flush
        File.rename(temp.path, destination)
      ensure
        temp.close!
      end
    end
  end
end
```

In `lib/svg_icon.rb`, add `require_relative "svg_icon/fetcher"` after the `require_relative "svg_icon/helper"` line.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib -Itest test/fetcher_test.rb`
Expected: all 7 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/svg_icon.rb lib/svg_icon/fetcher.rb test/fetcher_test.rb
git commit -m "feat: add Fetcher to download icon sets"
```

---

### Task 3: `SvgIcon::CLI` + `exe/svg_icon`

**Files:**
- Create: `lib/svg_icon/cli.rb`
- Create: `exe/svg_icon`
- Create: `test/cli_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/cli_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CliTest < Minitest::Test
  FakeFetcher = Struct.new(:name, :destination) do
    def fetch(name, destination)
      self.name = name
      self.destination = destination
    end
  end

  def test_fetch_downloads_into_icons_path
    fake = FakeFetcher.new
    SvgIcon::Fetcher.stub(:new, fake) do
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
    SvgIcon::Fetcher.stub(:new, proc { |_base_url, _http| raise SvgIcon::FetchError, "boom" }) do
      _, err = capture_io do
        error = assert_raises(SystemExit) { SvgIcon::CLI.run(["fetch", "bi"]) }
        assert_equal 1, error.status
      end
      assert_includes err, "boom"
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
```

Note: `SvgIcon::Fetcher.stub(:new, fake)` stubs `SvgIcon::Fetcher.new`; the CLI must call `SvgIcon::Fetcher.new` (with default args) so the stub intercepts it. The `proc` stub in `test_fetch_propagates_fetch_error` works because minitest calls the stub object's `call` when the stubbed method is invoked with matching args — the proc receives the same args `new` was called with.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec ruby -Ilib -Itest test/cli_test.rb`
Expected: FAIL with `NameError: uninitialized constant SvgIcon::CLI`.

- [ ] **Step 3: Implement CLI**

Create `lib/svg_icon/cli.rb`:

```ruby
# frozen_string_literal: true

module SvgIcon
  class CLI
    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      command = @argv.shift
      case command
      when "fetch"
        fetch
      when nil, "help", "--help", "-h"
        puts usage
      else
        warn "Unknown command: #{command}"
        warn usage
        exit 1
      end
    end

    private

    def fetch
      name = @argv.shift
      unless valid_name?(name) && @argv.empty?
        warn "Usage: svg_icon fetch <icon_set_name>"
        exit 1
      end

      destination = File.join(SvgIcon.configuration.icons_path, "#{name}.json")
      puts "Fetching #{name} from iconify/icon-sets"
      SvgIcon::Fetcher.new.fetch(name, destination)
      puts "Saved to #{relative_path(destination)}"
    rescue SvgIcon::FetchError => e
      warn e.message
      exit 1
    rescue StandardError => e
      warn "Error: #{e.message}"
      exit 1
    end

    def valid_name?(name)
      !name.nil? && !name.empty? && name.match?(/\A[a-z0-9\-_]+\z/)
    end

    def relative_path(path)
      path.sub("#{Dir.pwd}/", "")
    end

    def usage
      <<~TEXT
        Usage: svg_icon COMMAND

        Commands:
          fetch NAME    Download icon set NAME (e.g. bi) from iconify/icon-sets into #{SvgIcon.configuration.icons_path}
          help          Show this help
      TEXT
    end
  end
end
```

Create `exe/svg_icon` (make executable):

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "svg_icon"
require "svg_icon/cli"

exit(SvgIcon::CLI.run(ARGV) || 0)
```

In `lib/svg_icon.rb`, add `require_relative "svg_icon/cli"` after `require_relative "svg_icon/fetcher"`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec ruby -Ilib -Itest test/cli_test.rb`
Expected: all 7 tests PASS.

- [ ] **Step 5: Verify the executable works end-to-end**

Run: `chmod +x exe/svg_icon && bundle exec ruby exe/svg_icon fetch nonexistent-set-xyz && echo "UNEXPECTED SUCCESS" || echo "expected failure"`
Expected: `expected failure` (network 404 or resolve failure → non-zero exit). Then run `bundle exec ruby exe/svg_icon help` — expect usage text.

- [ ] **Step 6: Commit**

```bash
git add lib/svg_icon.rb lib/svg_icon/cli.rb exe/svg_icon test/cli_test.rb
git commit -m "feat: add svg_icon fetch CLI"
```

---

### Task 4: README + full verification

**Files:**
- Modify: `README.md`
- Test: all existing tests

- [ ] **Step 1: Update README**

Replace the `## Usage` section's initializer example block (the `SvgIcon.configure` code block) with:

```ruby
SvgIcon.configure do |config|
  # config.icon = "lucide" # icon set name: "lucide", "bi", "bx", "heroicons", or any fetched set
  config.icons_path = Rails.root.join("config", "svg_icons") # defaults to "config/svg_icons" under the project root

  ##
  # You can set a default class for icon
  config.default_class = ""
end
```

After the `<%= svg_icon("search") %>` usage example, add:

```markdown
## Fetching icon sets

The gem bundles a few icon sets (lucide, bi, bx, heroicons). To use any other
[iconify icon set](https://github.com/iconify/icon-sets/tree/master/json), download it into your project:

    $ svg_icon fetch bi

This downloads `bi.json` into `config/svg_icons/`. Set `config.icon = "bi"` to use it —
the gem looks for `<icon>.json` in `config/svg_icons/` first, then falls back to bundled data.

Commit `config/svg_icons/` to your repository so deploys don't need to re-fetch.
Re-run `svg_icon fetch <name>` to update an existing set.
```

- [ ] **Step 2: Run full test suite**

Run: `bundle exec rake test`
Expected: 40 runs, 0 failures, 0 errors (22 existing + 4 + 7 + 7 new).

- [ ] **Step 3: Verify gem packaging includes the executable**

Run: `gem build svg_icon.gemspec && tar -tf svg_icon-*.gem > /dev/null; rm svg_icon-*.gem`
Expected: build succeeds. The new `exe/svg_icon` is tracked by git (committed in Task 3), so `git ls-files` includes it and the gem ships it.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document svg_icon fetch CLI"
```
