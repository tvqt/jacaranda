# It's easy to add more libraries or choose different versions. Any libraries
# specified here will be installed and made available to your morph.io scraper.
# Find out more: https://morph.io/documentation/ruby

source "https://rubygems.org"

ruby "2.3.1"

gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"
gem "mechanize"
gem "rest-client"
gem "activesupport"
gem "octokit", "~> 4.0"
gem "json"
gem 'dotenv'

group :development do
  gem "pry"
end

group :test do
  gem 'rspec'
  gem 'webmock'
  gem 'vcr'
end
