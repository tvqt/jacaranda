# frozen_string_literal: true

require 'spec_helper'

describe 'PlanningAlerts' do
  let(:fortnight_start) { Date.parse('2017-07-24') }
  let(:fortnight_end)   { Date.parse('2017-08-06') }
  let(:last_fortnight)  { (fortnight_start..fortnight_end).to_a }

  describe 'GitHub' do
    it 'produces status text when there are commits' do
      VCR.use_cassette('github_commits_text_with_some_commits') do
        text = PlanningAlerts::GitHub.commits_text(period: last_fortnight)
        expect(text).to eq('You shipped 75 commits in the same period.')
      end
    end

    it 'produces a nil when there are no commits' do
      VCR.use_cassette('github_commits_text_with_no_commits') do
        text = PlanningAlerts::GitHub.commits_text(period: last_fortnight)
        expect(text).to be nil
      end
    end
  end

  describe 'Website' do
    it 'produces status text for new subscribers' do
      VCR.use_cassette('planningalerts_subscribers') do
        text = PlanningAlerts::Website.new_subscribers_text(period: last_fortnight)
        expect(text).to eq('714 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 6% less than the fortnight before.')
      end
    end

    it 'produces status text for new unsubscribers' do
      VCR.use_cassette('planningalerts_subscribers') do
        text = PlanningAlerts::Website.new_unsubscribers_text(period: last_fortnight)
        expect(text).to eq('171 people left. That’s 40% less than the fortnight before.')
      end
    end

    it 'produces status text for total subscribers' do
      VCR.use_cassette('planningalerts_subscribers') do
        text = PlanningAlerts::Website.total_subscribers_text
        expect(text).to eq('There are now 52,700 PlanningAlerts subscribers! :star2:')
      end
    end
  end

  describe 'Runner' do
    let(:url) { Faker::Internet.url('hooks.slack.com') }
    before(:each) do
      set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
    end

    context 'on Monday' do
      before(:each) do
        time_travel_to("next #{PlanningAlerts::Runner.post_day}")
      end

      it 'runs' do
        expect(PlanningAlerts::Runner.post_day).to eq('Monday')

        VCR.use_cassette('planningalerts_post_to_slack_webhook', match_requests_on: [:host]) do
          expect(PlanningAlerts::Runner.run).to be true
          expect(a_request(:post, url)).to have_been_made.times(1)
        end
      end
    end

    context 'on days other than Monday' do
      let(:days) { (1..6).map { |i| Date.parse(PlanningAlerts::Runner.post_day) + i } }

      it 'does not run' do
        days.each do |day|
          time_travel_to(day)
          expect(PlanningAlerts::Runner.run).to be false
          expect(a_request(:post, url)).to have_been_made.times(0)
        end
      end
    end
  end
end
