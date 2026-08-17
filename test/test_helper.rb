# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "svg_icon"

class Minitest::Test
  def setup
    SvgIcon.configuration = SvgIcon::Configuration.new
    SvgIcon.clear_cache!
  end

  def teardown
    SvgIcon.clear_cache!
  end
end