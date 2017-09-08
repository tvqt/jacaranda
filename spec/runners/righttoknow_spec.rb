# frozen_string_literal: true

require 'spec_helper'

describe 'RightToKnow' do
  let(:fortnight_start) { Date.parse('2017-07-24') }
  let(:fortnight_end)   { Date.parse('2017-08-06') }
  let(:last_fortnight)  { (fortnight_start..fortnight_end).to_a }

  describe 'Website' do
    it 'produces status text for new requests' do
      VCR.use_cassette('righttoknow_variety_sent') do
        text = RightToKnow::Website.new_requests_text(period: last_fortnight)
        expect(text).to eq(':saxophone: 27 new requests were made through Right To Know last fortnight.')
      end
    end

    it 'produces status text for annotations' do
      VCR.use_cassette('righttoknow_variety_comment') do
        text = RightToKnow::Website.annotations_text(period: last_fortnight)
        expect(text).to eq(':heartbeat: Our contributors helped people with 14 annotations.')
      end
    end

    it 'produces status text for successful requests' do
      VCR.use_cassette('righttoknow_status_successful') do
        text = RightToKnow::Website.success_text(period: last_fortnight)
        expect(text).to eq(':trophy: 7 requests were marked successful!')
      end
    end
  end

  describe 'Runner' do
    let(:url) { Faker::Internet.url('hooks.slack.com') }
    before(:each) do
      set_environment_variable('MORPH_SLACK_CHANNEL_WEBHOOK_URL', url)
    end

    context 'on Wednesday' do
      before(:each) do
        time_travel_to("next #{RightToKnow::Runner.post_day}")
      end

      it 'runs' do
        expect(RightToKnow::Runner.post_day).to eq('Wednesday')

        VCR.use_cassette('righttoknow_post_to_slack_webhook', match_requests_on: [:host]) do
          expect(RightToKnow::Runner.run).to be true
          expect(a_request(:post, url)).to have_been_made.times(1)
        end
      end
    end

    context 'on days other than Wednesday' do
      let(:days) { (1..6).map { |i| Date.parse(RightToKnow::Runner.post_day) + i } }

      it 'does not run' do
        days.each do |day|
          time_travel_to(day)
          expect(RightToKnow::Runner.run).to be false
          expect(a_request(:post, url)).to have_been_made.times(0)
        end
      end
    end
  end
end
