# frozen_string_literal: true

require "fileutils"
require "net/http"
require "openssl"
require "tempfile"
require "uri"

module SvgIcon
  class FetchError < Error; end

  class Fetcher
    DEFAULT_BASE_URL = "https://raw.githubusercontent.com/iconify/icon-sets/master/json"
    NAME_PATTERN = /\A[a-z0-9\-_]+\z/

    def initialize(base_url: DEFAULT_BASE_URL, http: Net::HTTP)
      @base_url = base_url
      @http = http
    end

    def fetch(name, destination)
      validate_name!(name)
      response = fetch_response(name)
      raise FetchError, "Failed to fetch #{name}: HTTP #{response.code}#{not_found_hint(response.code)}" unless response.code == "200"

      parse(response.body, name)
      write(response.body, destination)
      true
    end

    private

    def validate_name!(name)
      raise FetchError, "Invalid icon set name: #{name}" unless name.is_a?(String) && name =~ NAME_PATTERN
    end

    def fetch_response(name)
      @http.get_response(uri_for(name))
    rescue SocketError, SystemCallError, Timeout::Error, EOFError, IOError, OpenSSL::SSL::SSLError => e
      raise FetchError, "Failed to fetch #{name}: #{e.message}"
    end

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
