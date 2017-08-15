# frozen_string_literal: true

require 'spec_helper'

describe 'GitHub' do
  let(:fortnight_start) { Date.parse('2017-07-24') }
  let(:fortnight_end)   { Date.parse('2017-08-06') }
  let(:last_fortnight)  { (fortnight_start..fortnight_end).to_a }

  it 'produces status text when there are commits' do
    VCR.use_cassette('github_commits_text_with_some_commits') do
      text = GitHub.commits_text(period: last_fortnight)
      expect(text).to eq('You shipped 75 commits in the same period.')
    end
  end

  it 'produces a nil when there are no commits' do
    VCR.use_cassette('github_commits_text_with_no_commits') do
      text = GitHub.commits_text(period: last_fortnight)
      expect(text).to be nil
    end
  end
end
