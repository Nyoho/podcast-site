source "https://rubygems.org"

# Padrino supports Ruby version 1.9 and later
# ruby '2.3.1'

# Distribute your app as a gem
# gemspec

# Server requirements
# gem 'thin' # or mongrel
# gem 'trinidad', :platform => 'jruby'

# Optional JSON codec (faster performance)
# gem 'oj'

# Project requirements
gem "rake"

# Component requirements
gem "sassc"
gem "slim"

# Test requirements

# Padrino Stable Gem
gem "padrino", "~> 0.15.1"

gem "sinatra", "2.2.2"

# Or Padrino Edge
# gem 'padrino', :github => 'padrino/padrino-framework'

# Or Individual Gems
# %w(core support gen helpers cache mailer admin).each do |g|
#   gem 'padrino-' + g, '0.13.3.2'
# end

gem "sitespec"
gem "dotenv"
gem "twitter"
gem "mp3info"
gem "rss"

group :development do
  gem "pry"
  gem "pry-byebug"
  gem "puma"

  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rspec"
end
