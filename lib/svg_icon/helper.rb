module SvgIcon
  module Helper
    def svg_icon(name, options = {})
      options = options.dup

      icons = SvgIcon.icons
      height = icons["height"] || 24
      width = icons["width"] || 24

      options[:viewBox] = "0 0 #{width} #{height}"
      options[:version] = "1.1"

      default_class = SvgIcon.configuration.default_class

      options[:class] = "#{default_class} #{options[:class]}".strip if default_class.present?

      begin
        path = icons["icons"][name]["body"]
        "<svg xmlns='http://www.w3.org/2000/svg' #{icon_html_attributes(options)}>#{path}</svg>".html_safe
      rescue
        "<svg xmlns='http://www.w3.org/2000/svg' #{icon_html_attributes(options)}><!-- SVG icon file not found: '#{name}' --></svg></svg>".html_safe
      end
    end

    def icon_html_attributes(options)
      attrs = ""
      options.each { |attr, value| attrs += "#{attr}=\"#{value}\" " }
      attrs.strip
    end
  end
end
