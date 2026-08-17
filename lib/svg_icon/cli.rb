# frozen_string_literal: true

require_relative "fetcher"

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
      !name.nil? && name =~ SvgIcon::Fetcher::NAME_PATTERN
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
