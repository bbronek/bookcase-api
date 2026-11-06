CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "Style: Dockerfile",
    "docker run --rm -i -v ./.hadolint.yaml:/.config/hadolint.yaml hadolint/hadolint:v2.15.1 < Dockerfile"

  step "Security: gem audit", "bin/bundler-audit check --update"
  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Database: migrations run both ways and reproduce schema.rb",
    "RAILS_ENV=test bin/rails db:migrate:reset && RAILS_ENV=test bin/rails db:migrate VERSION=0 && " \
    "RAILS_ENV=test bin/rails db:migrate && git diff --exit-code db/schema.rb"
  step "Database: validations match constraints", "RAILS_ENV=test bundle exec database_consistency"

  step "Tests: RSpec with 100% line and branch coverage", "COVERAGE=1 bundle exec rspec"
  step "Docs: public/openapi/v1.yaml is up to date", "script/docs && git diff --exit-code public/openapi/v1.yaml"
end
