# frozen_string_literal: true

require_relative "svg_icon/configuration"
require_relative "svg_icon/helper"
require_relative "svg_icon/version"

require "multi_json"

module SvgIcon
  class Error < StandardError; end

  extend self
  def file_data
    @file_data ||= File.read(File.join(__dir__, "data/#{SvgIcon.configuration.icon}.json"))
  end

  def icons
    @icons ||= MultiJson.load(file_data).freeze
  end
end
