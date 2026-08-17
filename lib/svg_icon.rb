# frozen_string_literal: true

require_relative "svg_icon/configuration"
require_relative "svg_icon/helper"
require_relative "svg_icon/version"

require "multi_json"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/output_safety"

module SvgIcon
  class Error < StandardError; end

  extend self

  def icons
    @icons ||= {}
    @icons[icon] ||= MultiJson.load(file_data)
  end

  def icons_json
    @icons_json ||= {}
    @icons_json[cache_key] ||= merge_extra_icons(icons)
  end

  def clear_cache!
    @file_data = nil
    @icons = nil
    @icons_json = nil
    @extra_file_data = nil
    @extra_icons = nil
  end

  private

  def icon
    configuration.icon
  end

  def configuration
    SvgIcon.configuration
  end

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

  def extra_icons
    return {} unless configuration.extra_icons_path

    @extra_icons ||= {}
    @extra_icons[extra_path] ||= begin
      data = MultiJson.load(extra_file_data)
      raise Error, "Extra icons file must contain a JSON object: #{extra_path}" unless data.is_a?(Hash)

      data
    end
  end

  def extra_path
    configuration.extra_icons_path
  end

  def extra_file_data
    @extra_file_data ||= {}
    @extra_file_data[extra_path] ||= begin
      path = extra_path
      raise Error, "Extra icons file not found: #{path}" unless File.exist?(path)

      File.read(path)
    end
  end

  def merge_extra_icons(base_icons)
    icons_set = base_icons["icons"]
    raise Error, "Icon data must contain an 'icons' object: #{resolve_icon_path}" unless icons_set.is_a?(Hash)

    return base_icons if extra_icons.empty?

    merged = base_icons.dup
    merged["icons"] = icons_set.merge(extra_icons)
    merged
  end

  def cache_key
    "#{icon}:#{extra_path}"
  end
end
