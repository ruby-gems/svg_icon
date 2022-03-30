# frozen_string_literal: true

require_relative "svg_icon/configuration"
require_relative "svg_icon/helper"
require_relative "svg_icon/version"

require "multi_json"

module SvgIcon
  class Error < StandardError; end

  extend self

  def extra_file_data
    extra_data_path = SvgIcon.configuration.extra_icons_path
    return nil if extra_data_path.nil?
    @extra_file_data ||= File.read(extra_data_path)
  end

  def extra_icons
    return {} if extra_file_data.nil?
    @extra_icons ||= MultiJson.load(extra_file_data)
  end

  # def file_data
  #   icons_data_path = SvgIcon.configuration.icons_data_path

  #   icons_path = if icons_data_path.present?
  #     File.join(icons_data_path)
  #   else
  #     File.join(__dir__, "data/#{SvgIcon.configuration.icon}.json")
  #   end
  #   @file_data ||= File.read(icons_path)
  # end

  def file_data
    icons_path = File.join(__dir__, "data/#{SvgIcon.configuration.icon}.json")
    @file_data ||= File.read(icons_path)
  end

  def icons
    @icons ||= MultiJson.load(file_data)
  end

  def icons_json
    @icons_json ||= if extra_icons
      puts "icons_json"
      icons["icons"] = icons["icons"].merge(extra_icons)
      icons
    else
      icons
    end
  end
end
