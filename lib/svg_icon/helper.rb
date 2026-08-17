# frozen_string_literal: true

require "cgi"

module SvgIcon
  module Helper
    def svg_icon(name, options = {})
      options = options.dup
      icons = SvgIcon.icons_json

      height = icons["height"] || 24
      width = icons["width"] || 24

      options[:viewBox] ||= "0 0 #{width} #{height}"

      default_class = SvgIcon.configuration.default_class
      options[:class] = "#{default_class} #{options[:class]}".strip if default_class.present?

      body = icons.dig("icons", name.to_s, "body")

      content = if body
        body
      else
        "<!-- SVG icon file not found: '#{safe_comment_text(name.to_s)}' -->"
      end

      "<svg xmlns='http://www.w3.org/2000/svg' #{icon_html_attributes(options)}>#{content}</svg>".html_safe
    end

    private

    def icon_html_attributes(options)
      options.map do |attr, value|
        %(#{CGI.escapeHTML(attr.to_s)}="#{CGI.escapeHTML(value.to_s)}")
      end.join(" ")
    end

    def safe_comment_text(value)
      CGI.escapeHTML(value).gsub("-", "&#45;")
    end
  end
end
