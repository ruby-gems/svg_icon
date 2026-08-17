# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class HelperTest < Minitest::Test
  include SvgIcon::Helper

  def test_renders_svg_with_namespace_and_view_box
    output = svg_icon("search")
    assert_match %r{\A<svg xmlns='http://www.w3.org/2000/svg' viewBox="0 0 24 24">}, output
  end

  def test_renders_icon_body
    output = svg_icon("search")
    assert_includes output, '<circle cx="11" cy="11" r="8"/>'
  end

  def test_returns_html_safe_string
    assert_kind_of ActiveSupport::SafeBuffer, svg_icon("search")
  end

  def test_missing_icon_renders_comment
    output = svg_icon("does-not-exist")
    assert_includes output, "<!-- SVG icon file not found: 'does&#45;not&#45;exist' -->"
  end

  def test_comment_cannot_escape_with_double_dash
    output = svg_icon("a--b")
    refute_includes output, "a--b"
    assert_includes output, "a&#45;&#45;b"
  end

  def test_escapes_attribute_values
    output = svg_icon("search", class: %q(" onmouseover="alert(1)))
    assert_includes output, "&quot; onmouseover=&quot;alert(1)"
    refute_includes output, '" onmouseover="'
  end

  def test_keeps_user_provided_view_box
    output = svg_icon("search", viewBox: "0 0 32 32")
    assert_includes output, 'viewBox="0 0 32 32"'
  end

  def test_prepends_default_class
    SvgIcon.configure { |config| config.default_class = "icon-default" }
    output = svg_icon("search", class: "text-red-500")
    assert_includes output, 'class="icon-default text-red-500"'
  end

  def test_renders_extra_icon
    Dir.mktmpdir do |dir|
      path = File.join(dir, "extra.json")
      File.write(path, %({"custom": {"body": "<circle r='5'/>"}}))
      SvgIcon.configure { |config| config.extra_icons_path = path }
      output = svg_icon("custom")
      assert_includes output, "<circle r='5'/>"
    end
  end

  def test_does_not_mutate_passed_options
    options = { class: "text-red-500" }
    svg_icon("search", options)
    assert_equal({ class: "text-red-500" }, options)
  end
end