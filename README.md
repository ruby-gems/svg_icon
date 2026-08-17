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

```ruby
SvgIcon.configure do |config|
  # config.icon = "lucide" # icon set name: "lucide", "bi", "bx", "heroicons", or any fetched set
  config.icons_path = Rails.root.join("config", "svg_icons") # defaults to "config/svg_icons" under the project root

  ##
  # You can set a default class for icon
  config.default_class = ""
end
```

add ` include SvgIcon::Helper` to `ApplicationHelper`

```erb
<%= svg_icon("search") %>
```

## Fetching icon sets

The gem bundles a few icon sets (lucide, bi, bx, heroicons). To use any other
[iconify icon set](https://github.com/iconify/icon-sets/tree/master/json), download it into your project:

    $ svg_icon fetch bi

This downloads `bi.json` into `config/svg_icons/`. Set `config.icon = "bi"` to use it —
the gem looks for `<icon>.json` in `config/svg_icons/` first, then falls back to bundled data.

Commit `config/svg_icons/` to your repository so deploys don't need to re-fetch.
Re-run `svg_icon fetch <name>` to update an existing set.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/svg_icon.
