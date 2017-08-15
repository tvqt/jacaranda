# frozen_string_literal: true

require 'spec_helper'

describe 'validate_environment_varables!' do
  after(:each) { restore_env }

  it 'exits if any environment variables are not set' do
    Jacaranda::Runner.required_environment_variables.each { |var| unset_environment_variable(var) }
    method = -> { Jacaranda::Runner.validate_environment_variables! }
    expect(method).to raise_error(SystemExit)
  end
end

describe '#posted_in_last_fortnight?' do
  after(:each) { ScraperWiki.sqliteexecute('DELETE FROM data') }

  it 'returns true if record exists' do
    # Fake a successful post
    Jacaranda::Runner.record_successful_post(Faker::Lorem.paragraph(2))
    # Then test
    expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
  end

  it 'returns false if record does not exist' do
    expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
  end

  it 'returns false if posted > 14 days ago', :aggregate_failures do
    10.times {
      # Fake a successful post
      text = Faker::RickAndMorty.quote
      Jacaranda::Runner.record_successful_post(text)
      # Test now
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
      # Test the future
      time_travel_to(Date.today + 15.days)
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
    }
  end

  it 'handles no database' do
    # Create a new connection to new sqlite
    ScraperWiki.close_sqlite
    ScraperWiki.config = { db: Tempfile.new.path }
    ScraperWiki.sqlite_magic_connection.execute('PRAGMA database_list')
    # Test a query returns a false when there's no schema or data
    expect(Jacaranda::Runner.posted_in_last_fortnight?).to be false
    # Reset sqlite connection
    ScraperWiki.close_sqlite
    ScraperWiki.instance_variable_set(:@config, nil)
    ScraperWiki.instance_variable_set(:@sqlite_magic_connection, nil)
  end
end

describe '#posts' do
  let(:names) { 3.times.map { Faker::Name.first_name } }
  let(:runners) { names.map {|name| Object.const_set(name, Class.new(Jacaranda::Runner))}}

  after(:each) { ScraperWiki.sqliteexecute('DELETE FROM data') }

  it 'only returns posts for the runner type', :aggregate_failures do
    runners.each do |runner|
      (1..10).each do |n|
        text = Faker::RickAndMorty.quote
        time_travel_to(n.days.ago) { runner.record_successful_post(text) }
      end
    end

    runners.each do |runner|
      expect(runner.posts.size).to eq(10)
    end
  end
end

describe '#run' do
  let(:url) { Faker::Internet.url('hooks.slack.com') }
  before(:each) {
    set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
    set_environment_variable('MORPH_LIVE_MODE', 'true')
  }
  after(:each) {
    restore_env
    ScraperWiki.sqliteexecute('DELETE FROM data')
  }

  it 'does not run the scraper if posted in the last fortnight' do
    # Fake a successful post
    Jacaranda::Runner.record_successful_post(Faker::Lorem.paragraph(2))
    # Then run the runner
    expect(Jacaranda::Runner.run).to be false
  end

  it 'runs the scraper if there are no posts in the last fortnight' do
    VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
      expect(Jacaranda::Runner.run).to be true
      expect(a_request(:post, url)).to have_been_made.times(1)
    end
  end
end

describe 'post' do
  after(:each) { restore_env }
  after(:each) { ScraperWiki.sqliteexecute('DELETE FROM data') }

  it 'messages Slack' do
    VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
      url = Faker::Internet.url('hooks.slack.com')
      set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
      Jacaranda::Runner.post(Faker::Lorem.paragraph(2))
      expect(a_request(:post, url)).to have_been_made.times(1)
    end
  end

  it 'records the message if posting to Slack is successful' do
    VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
      url = Faker::Internet.url('hooks.slack.com')
      set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
      Jacaranda::Runner.post(Faker::Lorem.paragraph(2))
      expect(Jacaranda::Runner.posted_in_last_fortnight?).to be true
    end
  end

  it 'does not record the message if posting to Slack is unsuccessful'
end
