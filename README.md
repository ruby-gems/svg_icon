# SvgIcon

Svg icon render helper for rails

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'svg_icon'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install svg_icon

## Usage

Add `svg_icon.rb` in initializers folder

```
# frozen_string_literal: true

SvgIcon.configure do |config|
  # config.icon = "bi" # Options are "bi" and "bx"

  ##
  # You can set a default class for icon
  config.default_class = ""
end
```

add ` include SvgIcon::Helper` to `ApplicationHelper`

```erb
<%= svg_icon("search") %>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/svg_icon.
