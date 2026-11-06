require "rails_helper"

RSpec.describe "Repository" do
  it "pins one Ruby version in .ruby-version, the Dockerfile and Gemfile.lock" do
    ruby_version = Rails.root.join(".ruby-version").read.strip.delete_prefix("ruby-")

    expect(Rails.root.join("Dockerfile").read).to include("FROM docker.io/library/ruby:#{ruby_version}-slim AS base")
    expect(Rails.root.join("Gemfile.lock").read).to include("ruby #{ruby_version}")
  end
end
