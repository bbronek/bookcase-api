if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails" do
    enable_coverage :branch
    minimum_coverage line: 100, branch: 100
    skip %w[ /config/ /db/ /spec/ ]
  end
end

require "spec_helper"

ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("The specs delete data, so they run only in the test environment") unless Rails.env.test?
require "rspec/rails"

Rails.root.glob("spec/support/**/*.rb").sort.each { |file| require file }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => error
  abort error.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
