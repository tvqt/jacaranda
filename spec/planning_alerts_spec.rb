require 'spec_helper'

describe 'PlanningAlerts' do
  let(:beginning_of_fortnight) { Date.parse('2017-07-24') }
  let(:end_of_fortnight)       { Date.parse('2017-08-06') }
  let(:last_fortnight)         { (beginning_of_fortnight..end_of_fortnight).to_a }

  it 'produces status text for new subscribers' do
    VCR.use_cassette('planning_alerts_subscribers') do
      text = PlanningAlerts.new_subscribers_text(period: last_fortnight)
      expect(text).to eq('714 people signed up for PlanningAlerts last fortnight :revolving_hearts: That’s 6% less than the fortnight before.')
    end
  end

  it 'produces status text for new unsubscribers' do
    VCR.use_cassette('planning_alerts_subscribers') do
      text = PlanningAlerts.new_unsubscribers_text(period: last_fortnight)
      expect(text).to eq('171 people left. That’s 40% less than the fortnight before.')
    end
  end

  it 'produces status text for total subscribers' do
    VCR.use_cassette('planning_alerts_subscribers', record: :new_episodes) do
      text = PlanningAlerts.total_subscribers_text(period: last_fortnight)
      expect(text).to eq('There are now 52,700 PlanningAlerts subscribers! :star2:')
    end
  end
end
