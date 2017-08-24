# frozen_string_literal: true

require_relative('../scraper')
require 'pry'
require 'webmock/rspec'
require 'addressable'
require 'vcr'
require 'faker'
require 'delorean'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.shared_context 'mock runners' do
  let(:mock_runner_count) { 20 }
  let(:mock_runner_names) do
    sample_size = mock_runner_count * 2.5
    word_size   = 5
    sample = Array.new(sample_size) { Faker::Name.unique.first_name }
    sample.reject do |w|
      # skip non-word characters so we don't attempt to turn names like D'Angelo into objects
      # skip name <= 5 chars so there's an extremely low chance of partial matches
      # skip words that partial match other words
      w =~ /\W/ || w.size <= word_size || sample.grep(/#{w}/).size > 1
    end.sort[0..mock_runner_count - 1]
  end
  let(:mock_runners) do
    mock_runner_names.map { |name| Object.const_set(name, Class.new(Jacaranda::BaseRunner)) }
  end

  before(:each) { mock_runners }

  after(:each) do
    # Reset the whitelist
    Jacaranda.parse([])
    # Undefine all the runners we just created
    mock_runner_names.each { |name| Object.send(:remove_const, name) }
    # Reset webmock after every test
    WebMock.reset!
  end
end

RSpec.shared_context 'ScraperWiki' do
  before(:each) do
    # Create a new connection to new sqlite
    ScraperWiki.close_sqlite
    ScraperWiki.config = { db: ':memory:' }
    ScraperWiki.sqlite_magic_connection.execute('PRAGMA database_list')
  end

  after(:each) do
    # Reset sqlite connection
    ScraperWiki.close_sqlite
    ScraperWiki.instance_variable_set(:@config, nil)
    ScraperWiki.instance_variable_set(:@sqlite_magic_connection, nil)
  end
end

RSpec.configure do |config|
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true
  # Time-based test helper
  config.include Delorean

  # Set up a clean database for every test
  config.include_context 'ScraperWiki'

  # Set up mock runners for testing runners in isolation
  config.include_context 'mock runners'
end

def restore_env
  ENV.replace(@original) if @original
  @original = nil
end

def unset_environment_variable(name)
  @original ||= ENV.to_hash
  ENV.delete(name)
end

def set_environment_variable(name, value)
  @original ||= ENV.to_hash
  ENV[name] = value
end

def puts(*args); end
