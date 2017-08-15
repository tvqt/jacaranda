# frozen_string_literal: true

require 'dotenv'
Dotenv.load
require 'octokit'
require 'scraperwiki'
require 'mechanize'
require 'rest-client'
require 'json'
require 'active_support/all'

# Duck punches
class Numeric
  def percent_of(n)
    to_f / n.to_f * 100.0
  end
end

# PlanningAlerts contributor stats from GitHub
class GitHub
  class << self
    def commits_text(period:)
      puts 'Collect information from GitHub'
      if commits_count(period: period).zero?
        nil
      else
        "You shipped #{commits_count(period: period)} commits in the same period."
      end
    end

    private

    def commits_count(period:)
      github = Octokit::Client.new
      github.auto_paginate = true
      repo = 'openaustralia/planningalerts'
      params = { since: period.first, until: period.last }
      commits = github.commits(repo, params)
      commits.size
    end
  end
end

# PlanningAlerts stats from PlanningAlerts
class PlanningAlerts
  class << self
    def new_subscribers_text(period:)
      before_period = determine_period_before(period)

      puts 'Collect new subscriber information from PlanningAlerts'
      period_count        = count('new_alert_subscribers', period: period)
      period_before_count = count('new_alert_subscribers', period: before_period)

      [
        period_count,
        'people signed up for PlanningAlerts last fortnight :revolving_hearts:',
        change_sentence(period_count, period_before_count)
      ].join(' ')
    end

    def new_unsubscribers_text(period:)
      before_period = determine_period_before(period)

      puts 'Collect new unsubscriber information from PlanningAlerts'
      period_count        = count('emails_completely_unsubscribed', period: period)
      period_before_count = count('emails_completely_unsubscribed', period: before_period)

      [
        period_count,
        'people left.',
        change_sentence(period_count, period_before_count)
      ].join(' ')
    end

    def total_subscribers_text
      puts 'Collect total subscribers information from PlanningAlerts'
      number = total_planningalerts_subscribers.round(-2)
      format = { precision: 0, delimiter: ',' }
      [
        'There are now',
        ActiveSupport::NumberHelper.number_to_rounded(number, format),
        'PlanningAlerts subscribers! :star2:'
      ].join(' ')
    end

    private

    def determine_period_before(period)
      (period.first.advance(weeks: -2)..period.last.advance(weeks: -2)).to_a
    end

    def total_planningalerts_subscribers
      # Memoize if we have fetched the data before
      return @subscribers_count if @subscribers_count
      # Otherwise pull the data from the PlanningAlerts website
      page = Mechanize.new.get('https://www.planningalerts.org.au/performance')
      @subscribers_count = page.at('#content h2').text.split(' ').first.to_i
    end

    def percentage_change_in_words(change)
      [
        change.to_s.delete('-') + '%',
        (change.positive? ? 'more' : 'less')
      ].join(' ')
    end

    def change_sentence(last_fortnight, fortnight_before_last)
      percentage_change_from_fortnight_before = last_fortnight.percent_of(fortnight_before_last) - 100
      percentage_change_from_fortnight_before = percentage_change_from_fortnight_before.round(1).floor

      [
        'That’s',
        percentage_change_in_words(percentage_change_from_fortnight_before),
        'than the fortnight before.'
      ].join(' ')
    end

    def subscribers_data
      # Memoize if we have fetched the data before
      return @subscribers_data if @subscribers_data
      # Otherwise fetch the data, with a _long_ timeout.
      url = 'https://www.planningalerts.org.au/performance/alerts.json'
      response = RestClient::Request.execute(method: :get, url: url, timeout: 300)
      @subscribers_data = JSON.parse(response)
    end

    def count(attribute, period:)
      count = 0

      period.each do |date|
        subscribers_data.each do |row|
          count += row[attribute] if row['date'] == date.to_s
        end
      end

      count
    end
  end
end

# The scraper
class Scraper
  class << self
    def run
      validate_environment_varables!

      if posted_in_last_fortnight?
        puts 'We have not posted an update during this fortnight.'
        scrape_and_post_message
      else
        puts 'We have posted an update during this fortnight.'
      end
    end

    def required_environment_variables
      %w[MORPH_GITHUB_OAUTH_ACCESS_TOKEN MORPH_SLACK_CHANNEL_WEBHOOK_URL]
    end

    def validate_environment_variables!
      return if required_environment_variables.all? { |var| ENV[var] }

      puts 'The scraper needs the following environment variables set:'
      puts
      puts required_environment_variables.join("\n")
      exit(1)
    end

    def posted_in_last_fortnight?
      query = "* from data where `date_posted`>'#{1.fortnight.ago.to_date}'"
      ScraperWiki.select(query).any?
    rescue
      false
    end

    def morph_live_mode?
      ENV['MORPH_LIVE_MODE'] == 'true'
    end

    def scrape_and_post_message
      message = build_message

      if morph_live_mode?
        puts 'Posting the message to Slack'
        post(message)
      else
        puts 'Not posting to Slack'
        puts 'Not recording the message in the database'
        print(message)
      end
    end

    def post_message_to_slack(text, opts = {})
      options = {
        username: 'Jacaranda',
        text: text
      }.merge(opts)
      url = options.delete(:url)
      raise ArgumentError, 'Must supply :url in options' unless url

      RestClient.post(url, options.to_json) =~ /ok/i
    end

    def last_fortnight
      start  = 1.fortnight.ago.beginning_of_week.to_date
      finish = 1.week.ago.end_of_week.to_date
      (start..finish).to_a
    end

    def build_message
      [
        PlanningAlerts.new_subscribers_text(period: last_fortnight),
        PlanningAlerts.new_unsubscribers_text(period: last_fortnight),
        GitHub.commits_text(period: last_fortnight),
        PlanningAlerts.total_subscribers_text
      ].compact.join("\n\n")
    end

    def post(message)
      opts = { url: ENV['MORPH_SLACK_CHANNEL_WEBHOOK_URL'] }
      opts[:channel] = '#bottesting' unless morph_live_mode?
      if post_message_to_slack(message, opts)
        puts 'Recording the message in the database'
        record_successful_post(message)
      else
        puts 'Error: could not post the message to Slack!'
      end
    end

    def record_successful_post(message)
      ScraperWiki.save_sqlite([:date_posted], date_posted: Date.today.to_s, text: message)
    end

    def print(message)
      puts
      puts message.gsub(/^/m, '> ')
    end
  end
end

Scraper.run if $PROGRAM_NAME == __FILE__
