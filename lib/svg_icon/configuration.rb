# frozen_string_literal: true

module SvgIcon
  class Configuration
    DEFAULT_ICON = "bi"

    attr_accessor :icon
    attr_accessor :default_class

    def initialize
      @icon = DEFAULT_ICON
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
  end
end
