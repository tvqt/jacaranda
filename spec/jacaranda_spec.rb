# frozen_string_literal: true

require 'spec_helper'

def all_requests
  WebMock::RequestRegistry.instance.requested_signatures.hash.keys
end

def all_request_bodies
  all_requests.map { |r| JSON.parse(r.body) }
end

describe 'Jacaranda' do
  describe '.fix_incorrectly_migrated_data!' do
    let(:create_table_statements) do
      [
        %[CREATE TABLE data (date_posted,text,runner,UNIQUE (date_posted))],
        %[CREATE TABLE posts (date_posted,text,runner,UNIQUE (date_posted,runner))]
      ]
    end

    before(:each) do
      create_table_statements.each { |statement| ScraperWiki.sqliteexecute(statement) }
      insert_data_statements.each { |statement| ScraperWiki.sqliteexecute(statement) }
    end

    context 'when the data has not been fixed' do
      # rubocop:disable Metrics/LineLength
      let(:insert_data_statements) do
        [
          %[INSERT INTO "posts" VALUES('2016-08-29','700 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 6% down from the fortnight before. You shipped 26 commits in the same period. There are now 36.8 thousand PlanningAlerts subscribers! :star2:','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2016-09-12','705 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 3% up from the fortnight before. You shipped 1 commits in the same period. There are now 37.4 thousand PlanningAlerts subscribers! :star2:','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2016-09-26','746 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 6% up from the fortnight before. You shipped 13 commits in the same period. There are now 38 thousand PlanningAlerts subscribers! :star2:','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2016-10-10','728 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 0% down from the fortnight before. There are now 38.6 thousand PlanningAlerts subscribers! :star2:','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2016-10-25','745 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 5% up from the fortnight before. There are now 39.3 thousand PlanningAlerts subscribers! :star2:','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2017-09-04',':saxophone: 31 new requests were made through Right To Know last fortnight.\n\n:heartbeat: Our contributors helped people with 7 annotations.\n\n:trophy: 3 requests were marked successful!','RightToKnow::Runner')],
          %[INSERT INTO "posts" VALUES('2017-09-05','711 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 13% less than the fortnight before.\n\n232 people left. That’s 5% less than the fortnight before.\n\nYou shipped 100 commits in the same period.\n\nThere are now 53,700 PlanningAlerts subscribers! :star2:','PlanningAlerts::Runner')]
        ]
      end
      # rubocop:enable Metrics/LineLength

      it 'applies the fix' do
        Jacaranda.fix_incorrectly_migrated_data!

        query = %(SELECT count(*) AS count FROM posts)
        expect(ScraperWiki.sqliteexecute(query).first['count']).to eq(insert_data_statements.size)

        query = %(SELECT * FROM posts WHERE runner IS NULL)
        expect(ScraperWiki.sqliteexecute(query).empty?).to be true
      end
    end

    context 'when the data has been fixed' do
      # rubocop:disable Metrics/LineLength
      let(:insert_data_statements) do
        [
          %(INSERT INTO posts (date_posted,text,runner) VALUES ('2016-08-29','Right To Know','RightToKnow::Runner')),
          %(INSERT INTO posts (date_posted,text,runner) VALUES ('2016-09-12','Right To Know','RightToKnow::Runner')),
          %(INSERT INTO posts (date_posted,text,runner) VALUES ('2017-09-04','PlanningAlerts','PlanningAlerts::Runner')),
          %(INSERT INTO posts (date_posted,text,runner) VALUES ('2017-09-04','Right To Know','RightToKnow::Runner'))
        ]
      end
      # rubocop:enable Metrics/LineLength

      it 'skips the fix' do
        query = %(SELECT * FROM posts)
        before = ScraperWiki.sqliteexecute(query)

        Jacaranda.fix_incorrectly_migrated_data!

        query = %(SELECT count(*) AS count FROM posts)
        expect(ScraperWiki.sqliteexecute(query).first['count']).to eq(insert_data_statements.size)

        query = %(SELECT * FROM posts)
        after = ScraperWiki.sqliteexecute(query)

        expect(before).to eq(after)
      end
    end
  end

  describe '.parse' do
    context 'when filtering' do
      it 'sorts runners alphabetically' do
        runners = Jacaranda.runners
        expect(runners.size).to be > 0
        expect(runners).to eq(runners.sort_by(&:to_s))
      end

      context 'with cli options' do
        it 'can filter to a single runner', :aggregate_failures do
          runner = Jacaranda.runners.first
          args = %w[--runners] << runner.to_s.split('::').first
          Jacaranda.parse(args)
          expect(Jacaranda.runners.size).to eq(1)
          expect(Jacaranda.runners).to eq([runner])
        end

        it 'can filter to multiple runners', :aggregate_failures do
          runners = Jacaranda.runners[0..1]
          args = %w[--runners] << runners.map(&:to_s).map { |r| r.split('::').first }.join(',')
          Jacaranda.parse(args)
          expect(Jacaranda.runners.size).to eq(2)
          expect(Jacaranda.runners).to eq(Jacaranda.runners[0..1])
        end
      end

      context 'with environment variables' do
        let(:single_runner) { Jacaranda.runners.first }
        let(:multiple_runners) { Jacaranda.runners[0..1] }
        let(:single_runner_name) do
          single_runner.to_s.split('::').first
        end
        let(:multiple_runner_names) do
          multiple_runners.map(&:to_s).map { |r| r.split('::').first }.join(',')
        end

        it 'can filter to a single runner', :aggregate_failures do
          set_environment_variable('MORPH_RUNNERS', single_runner_name)
          Jacaranda.parse
          expect(Jacaranda.runners.size).to eq(1)
          expect(Jacaranda.runners).to eq([single_runner])
        end

        it 'can filter to multiple runners', :aggregate_failures do
          set_environment_variable('MORPH_RUNNERS', multiple_runner_names)
          Jacaranda.parse
          expect(Jacaranda.runners.size).to eq(2)
          expect(Jacaranda.runners).to eq(multiple_runners)
        end

        after(:each) { restore_env }
      end
    end
  end

  describe '.run' do
    let(:url) { Faker::Internet.url('hooks.slack.com') }
    let(:text) { Faker::Lorem.paragraph(2) }
    let(:mock_runner_names) { %w[Alpha Bravo Charlie Delta Echo Foxtrot].shuffle }
    let(:mock_runners) do
      mock_runner_names.map do |name|
        Object.const_set(name, Class.new(Jacaranda::BaseRunner))
      end
    end

    before(:each) do
      set_environment_variable('MORPH_LIVE_MODE', 'true')
      set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
      mock_runners
    end

    it 'executes the runners in alphabetical order' do
      vcr_options = { match_requests_on: [:host], allow_playback_repeats: true }
      VCR.use_cassette('post_to_slack_webhook', vcr_options) do
        args = ['--runners', mock_runner_names.join(',')]
        Jacaranda.run(args)

        requested_names = all_request_bodies.map { |b| b['text'][/inherit (\w+) and/, 1] }
        expect(requested_names).to eq(mock_runner_names.sort)

        expect(a_request(:post, url)).to have_been_made.times(mock_runner_names.size)
      end
    end

    it 'exits after listing runners' do
      args = ['--list-runners']
      expect { Jacaranda.run(args) }.to raise_error(SystemExit)
    end

    after(:each) do
      mock_runner_names.each { |name| Object.send(:remove_const, name) }
    end
  end
end
