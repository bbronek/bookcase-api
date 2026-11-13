source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.4"
gem "pg", "~> 1.7"
gem "puma", "~> 8.0"
gem "bootsnap", require: false
gem "panko_serializer", "~> 1.0.1"
gem "solid_queue", "~> 1.7"
gem "tzinfo-data", platforms: %i[ windows jruby ]

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "rswag-specs"

  gem "rubocop-rails-omakase", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-factory_bot", require: false

  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "database_consistency", require: false
  gem "lefthook", require: false
end

group :development do
  gem "annotaterb", require: false
end

group :test do
  gem "json_schemer"
  gem "shoulda-matchers"
  gem "simplecov", require: false
end
