# frozen_string_literal: true

source "https://rubygems.org"

# Rails version can be specified via RAILS_VERSION env var
rails_version = ENV.fetch("RAILS_VERSION", "~> 8.0.0")
gem "rails", rails_version

# Core Rails dependencies
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Database (using SQLite for dummy app)
gem "sqlite3", ">= 2.0"

# Web server for testing
gem "puma", ">= 5.0"

# Add the parent gem (the one being tested)
# This assumes the parent gem is a Rails engine
parent_gem_path = File.expand_path("../..", __dir__)
parent_gemspec = Dir.glob(File.join(parent_gem_path, "*.gemspec")).first

if parent_gemspec
  parent_gem_name = File.basename(parent_gemspec, ".gemspec")
  gem parent_gem_name, path: parent_gem_path
end

group :development, :test do
  gem "debug"
end