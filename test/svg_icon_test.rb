# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class SvgIconTest < Minitest::Test
  def test_default_configuration_uses_lucide
    assert_equal "lucide", SvgIcon.configuration.icon
  end

  def test_configure_yields_configuration
    SvgIcon.configure { |config| config.default_class = "icon" }
    assert_equal "icon", SvgIcon.configuration.default_class
  end

  def test_icons_loads_icon_data
    icons = SvgIcon.icons
    assert_instance_of Hash, icons["icons"]
    assert_equal "lucide", icons["prefix"]
  end

  def test_icons_follows_configuration_icon
    SvgIcon.configure { |config| config.icon = "bx" }
    assert_equal "bx", SvgIcon.icons["prefix"]
  end

  def test_icons_raises_when_data_file_missing
    SvgIcon.configure { |config| config.icon = "nonexistent" }
    error = assert_raises(SvgIcon::Error) { SvgIcon.icons }
    assert_match(/Icon data file not found/, error.message)
  end

  def test_icons_json_merges_extra_icons
    with_extra_icons(%({"custom-icon": {"body": "<circle r='5'/>"}})) do
      assert_includes SvgIcon.icons_json["icons"], "custom-icon"
    end
  end

  def test_extra_icons_override_built_in_icons
    with_extra_icons(%({"search": {"body": "<custom-icon/>"}})) do
      assert_equal "<custom-icon/>", SvgIcon.icons_json["icons"]["search"]["body"]
    end
  end

  def test_icons_json_does_not_mutate_icons
    with_extra_icons(%({"custom-icon": {"body": "<circle r='5'/>"}})) do
      icons_before = SvgIcon.icons["icons"].keys
      SvgIcon.icons_json
      assert_equal icons_before, SvgIcon.icons["icons"].keys
    end
  end

  def test_extra_icons_raises_when_file_missing
    SvgIcon.configure { |config| config.extra_icons_path = "/nonexistent/extra.json" }
    error = assert_raises(SvgIcon::Error) { SvgIcon.icons_json }
    assert_match(/Extra icons file not found/, error.message)
  end

  def test_extra_icons_raises_when_data_not_an_object
    with_extra_icons("[1, 2, 3]") do
      error = assert_raises(SvgIcon::Error) { SvgIcon.icons_json }
      assert_match(/must contain a JSON object/, error.message)
    end
  end

  def test_configuration_change_switches_cached_data
    SvgIcon.icons
    SvgIcon.configure { |config| config.icon = "bx" }
    assert_equal "bx", SvgIcon.icons["prefix"]
  end

  def test_clear_cache_reloads_extra_file
    with_extra_icons(%({"first": {"body": "1"}})) do
      SvgIcon.icons_json
      File.write(SvgIcon.configuration.extra_icons_path, %({"second": {"body": "2"}}))
      SvgIcon.clear_cache!
      assert_includes SvgIcon.icons_json["icons"], "second"
    end
  end

  private

  def with_extra_icons(contents)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "extra.json")
      File.write(path, contents)
      SvgIcon.configure { |config| config.extra_icons_path = path }
      yield
    end
  end
end