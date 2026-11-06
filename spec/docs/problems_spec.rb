require "rails_helper"

RSpec.describe "Problem types page" do
  it "documents every problem type the API answers with, and nothing else" do
    Rails.autoloaders.main.eager_load_dir(Rails.root.join("app/domains"))
    page = Rails.public_path.join("problems/index.html").read

    expect(page.scan(/<dt id="([a-z-]+)">/).flatten).to match_array(DomainError.descendants.filter_map(&:problem_type).uniq)
  end
end
