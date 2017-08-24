# frozen_string_literal: true

require 'spec_helper'

def all_requests
  WebMock::RequestRegistry.instance.requested_signatures.hash.keys
end

def all_request_bodies
  all_requests.map { |r| JSON.parse(r.body) }
end

describe 'Jacaranda' do
  describe 'BaseRunner' do
    describe '#validate_environment_varables!' do
      let(:envvars) { Jacaranda::BaseRunner.required_environment_variables }
      subject { -> { Jacaranda::BaseRunner.validate_environment_variables! } }

      context 'when all environment variables are set' do
        before(:each) { envvars.each { |var| set_environment_variable(var, Faker::Name.first_name) } }

        it { is_expected.to_not raise_error }
      end

      context 'when any environment variables are not set' do
        before(:each) { envvars.each { |var| unset_environment_variable(var) } }

        it { is_expected.to raise_error(SystemExit) }
      end

      after(:each) { restore_env }
    end

    describe '#posted_in_last_fortnight?' do
      let(:text) { Faker::Lorem.paragraph(2) }

      context 'if record exists' do
        it do
          # Fake a successful post
          Jacaranda::BaseRunner.record_successful_post(text)
          # Then test
          expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be true
        end
      end

      context 'if record does not exist' do
        it do
          expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be false
        end
      end

      context 'if posted > 14 days ago' do
        it nil, :aggregate_failures do
          10.times do
            # Fake a successful post
            text = Faker::RickAndMorty.quote
            Jacaranda::BaseRunner.record_successful_post(text)
            # Test now
            expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be true
            # Test the future
            time_travel_to(Date.today + 15.days)
            expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be false
          end
        end
      end

      context 'when there is no schema or data' do
        it do
          expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be false
        end
      end
    end

    describe '#posts' do
      let(:names) { Array.new(3) { Faker::Name.unique.first_name } }
      let(:runners) do
        sorted = names.sort_by { |c| c.to_s.split('::').last }
        sorted.map { |name| Object.const_set(name, Class.new(Jacaranda::BaseRunner)) }
      end
      let(:count) { 10 }

      it 'only returns posts for the runner type', :aggregate_failures do
        runners.each do |runner|
          (1..count).each do |n|
            text = Faker::RickAndMorty.quote
            time_travel_to(n.days.ago) { runner.record_successful_post(text) }
          end
        end

        runners.each do |runner|
          expect(runner.posts.size).to eq(count)
        end
      end

      after(:each) { ScraperWiki.sqliteexecute('DELETE FROM data') }
    end

    describe '.run' do
      let(:url) { Faker::Internet.url('hooks.slack.com') }
      let(:text) { Faker::Lorem.paragraph(2) }

      before(:each) do
        set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
        set_environment_variable('MORPH_LIVE_MODE', 'true')
      end

      context 'posted in the last fortnight' do
        it 'does not run the scraper' do
          # Fake a successful post
          Jacaranda::BaseRunner.record_successful_post(text)
          # Then run the runner
          expect(Jacaranda::BaseRunner.run).to be false
        end
      end

      context 'not posted in the last fortnight' do
        it 'runs the scraper' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            expect(Jacaranda::BaseRunner.run).to be true
            expect(a_request(:post, url)).to have_been_made.times(1)
          end
        end
      end

      after(:each) do
        restore_env
        ScraperWiki.sqliteexecute('DELETE FROM data')
      end
    end

    describe '#post_to_slack' do
      let(:url) { Faker::Internet.url('hooks.slack.com') }
      let(:text) { Faker::Lorem.paragraph(2) }

      before(:each) { set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url) }

      context 'posting to Slack is successful' do
        it 'POSTs to webhook URL' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(a_request(:post, url)).to have_been_made.times(1)
          end
        end

        it 'records the message' do
          VCR.use_cassette('post_to_slack_webhook', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be true
          end
        end
      end

      context 'posting to Slack is not successful' do
        it 'does not record the message' do
          VCR.use_cassette('post_to_slack_webhook_but_fails', match_requests_on: [:host]) do
            Jacaranda::BaseRunner.post(text)
            expect(Jacaranda::BaseRunner.posted_in_last_fortnight?).to be false
          end
        end
      end

      after(:each) do
        restore_env
      end
    end
  end

  describe '.runners' do
    let(:count) { 20 }
    let(:names) do
      sample_size = count * 2.5
      word_size   = 5
      sample = Array.new(sample_size) { Faker::Name.unique.first_name }
      sample.reject do |w|
        # skip non-word characters so we don't attempt to turn names like D'Angelo into objects
        # skip name <= 5 chars so there's an extremely low chance of partial matches
        # skip words that partial match other words
        w =~ /\W/ || w.size <= word_size || sample.grep(/#{w}/).size > 1
      end.sort[0..count - 1]
    end
    let(:runners) do
      names.map { |name| Object.const_set(name, Class.new(Jacaranda::BaseRunner)) }
    end

    before(:each) { runners }

    context 'when filtering' do
      it 'returns everything by default' do
        Jacaranda.parse([])
        expect(Jacaranda.runners.size).to be >= count
      end

      it 'can filter to a single runner', :aggregate_failures do
        args = %w[--runners] << runners.first.to_s
        Jacaranda.parse(args)
        expect(Jacaranda.runners.size).to eq(1)
        expect(Jacaranda.runners).to eq([runners.first])
      end

      it 'can filter to multiple runners', :aggregate_failures do
        args = %w[--runners] << runners[0..1].join(',')
        Jacaranda.parse(args)
        expect(Jacaranda.runners.size).to eq(2)
        expect(Jacaranda.runners).to eq(runners[0..1])
      end

      it 'sorts runners alphabetically' do
        expect(Jacaranda.runners.size).to be >= count
        expect(Jacaranda.runners).to eq(Jacaranda.runners.sort_by(&:to_s))
      end
    end

    context '.run' do
      let(:url) { Faker::Internet.url('hooks.slack.com') }
      let(:text) { Faker::Lorem.paragraph(2) }

      before(:each) do
        set_environment_variable('MORPH_LIVE_MODE', 'true')
        set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
      end

      it 'executes the runners in alphabetical order' do
        vcr_options = { match_requests_on: [:host], allow_playback_repeats: true }
        VCR.use_cassette('post_to_slack_webhook', vcr_options) do
          args = ['--runners', names.join(',')]
          Jacaranda.run(args)

          requested_names = all_request_bodies.map { |b| b['text'][/inherit (\w+) and/, 1] }
          requested_names &= names # because sometimes there are partial matches
          expect(requested_names).to eq(names.sort)

          expect(a_request(:post, url)).to have_been_made.at_least_times(count)
        end
      end

      it 'exits after listing runners' do
        args = ['--list-runners']
        expect { Jacaranda.run(args) }.to raise_error(SystemExit)
      end
    end

    after(:each) do
      # Reset the whitelist
      Jacaranda.parse([])
      # Undefine all the runners we just created
      names.each { |name| Object.send(:remove_const, name) }
      # Reset webmock after every test
      WebMock.reset!
    end
  end
end
