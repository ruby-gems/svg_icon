# frozen_string_literal: true

module SvgIcon
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

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configuration=(config)
    @configuration = config
  end

  def self.configure
    yield configuration
    SvgIcon.clear_cache!
  end
end
