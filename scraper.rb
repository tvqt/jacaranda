require 'dotenv'
Dotenv.load
require 'octokit'
require 'scraperwiki'
require 'mechanize'
require 'rest-client'
require 'json'
require 'active_support/all'

def morph_live_mode?
  ENV['MORPH_LIVE_MODE'] == 'true'
end

def posted_in_last_fortnight?
  ScraperWiki.select("* from data where `date_posted`>'#{1.fortnight.ago.to_date.to_s}'").empty?
rescue
  true
end

def post_message_to_slack(text, opts={})
  options = {
    username: 'Jacaranda',
    text: text,
  }.merge(opts)
  url = options.delete(:url)
  raise ArgumentError, "Must supply :url in options" unless url

  RestClient.post(url, options.to_json)
end

class Numeric
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
end

class GitHub
  class << self
    def git_commits_between_dates(start, finish)
      # FIXME(auxesis): this being set so deep is a smell
      access_token = ENV['MORPH_GITHUB_OAUTH_ACCESS_TOKEN']
      github = Octokit::Client.new(access_token: access_token)
      path = "repos/openaustralia/planningalerts/commits?since=#{start.to_s}&until=#{finish.to_s}"
      response = github.get(path)

      commits_count = response.count

      last_response = github.last_response
      until last_response.rels[:next].nil?
        last_response = last_response.rels[:next].get
        commits_count += last_response.data.count
      end

      commits_count
    end

    def commits_text(period:)
      puts 'Collect information from GitHub'
      commits_count = git_commits_between_dates(period.first, period.last)
      if commits_count.zero?
        commits_text = nil
      else
        commits_text = "You shipped #{commits_count} commits in the same period."
      end
    end
  end
end

class PlanningAlerts
  class << self
    def new_subscribers_text(period:)
      before_period = determine_period_before(period)

      puts 'Collect new subscriber information from PlanningAlerts'
      period_count        = get_planningalerts_data_between('new_alert_subscribers', period.first, period.last)
      period_before_count = get_planningalerts_data_between('new_alert_subscribers', before_period.first, before_period.last)

      [
        period_count,
        'people signed up for PlanningAlerts last fortnight :revolving_hearts:',
        change_sentence(period_count, period_before_count),
      ].join(' ')
    end

    def new_unsubscribers_text(period:)
      before_period = determine_period_before(period)

      puts 'Collect new unsubscriber information from PlanningAlerts'
      period_count        = get_planningalerts_data_between('emails_completely_unsubscribed', period.first, period.last)
      period_before_count = get_planningalerts_data_between('emails_completely_unsubscribed', before_period.first, before_period.last)

      [
        period_count,
        'people left.',
        change_sentence(period_count, period_before_count),
      ].join(' ')
    end

    def total_subscribers_text(period:)
      puts 'Collect total subscribers information from PlanningAlerts'
      number = total_planningalerts_subscribers.round(-2)
      format = { precision: 0, delimiter: ',' }
      [
        'There are now',
        ActiveSupport::NumberHelper.number_to_rounded(number, format),
        'PlanningAlerts subscribers! :star2:',
      ].join(' ')
    end

    private

    def determine_period_before(period)
      (period.first.advance(weeks: -2)..period.last.advance(weeks: -2)).to_a
    end

    def total_planningalerts_subscribers
      # Memoize if we have fetched the data before
      return @total_planningalerts_subscribers if @total_planningalerts_subscribers
      # Otherwise pull the data from the PlanningAlerts website
      page = Mechanize.new.get('https://www.planningalerts.org.au/performance')
      @total_planningalerts_subscribers = page.at('#content h2').text.split(' ').first.to_i
    end

    def percentage_change_in_words(change)
      text = change.to_s.delete('-') + '% '
      text += change > 0 ? 'more' : 'less'
      text
    end

    def change_sentence(last_fortnight, fortnight_before_last)
      percentage_change_from_fortnight_before = last_fortnight.percent_of(fortnight_before_last)- 100
      percentage_change_from_fortnight_before = percentage_change_from_fortnight_before.round(1).floor

      [
        'That’s',
        percentage_change_in_words(percentage_change_from_fortnight_before),
        'than the fortnight before.',
      ].join(' ')
    end

    def planningalerts_subscribers_data
      # Memoize if we have fetched the data before
      return @planningalerts_subscribers_data if @planningalerts_subscribers_data
      # Otherwise fetch the data, with a _long_ timeout.
      url = 'https://www.planningalerts.org.au/performance/alerts.json'
      response = RestClient::Request.execute(method: :get, url: url, timeout: 300)
      @planningalerts_subscribers_data = JSON.parse(response)
    end

    def get_planningalerts_data_between(attribute, start_date, end_date)
      new_signups_for_period = 0

      period = (start_date..end_date).to_a
      period.each do |date|
        planningalerts_subscribers_data.each do |row|
          if row['date'].eql? date.to_s
            new_signups_for_period += row[attribute]
          end
        end
      end

      new_signups_for_period
    end
  end
end

def build_message
  beginning_of_fortnight = 1.fortnight.ago.beginning_of_week.to_date
  end_of_fortnight       = 1.week.ago.end_of_week.to_date
  last_fortnight         = (beginning_of_fortnight..end_of_fortnight).to_a

  text = [
    PlanningAlerts.new_subscribers_text(period: last_fortnight),
    PlanningAlerts.new_unsubscribers_text(period: last_fortnight),
    GitHub.commits_text(period: last_fortnight),
    PlanningAlerts.total_subscribers_text(period: last_fortnight),
  ].compact

  text.join("\n\n")
end

def required_environment_variables
  [
    'MORPH_GITHUB_OAUTH_ACCESS_TOKEN',
    'MORPH_SLACK_CHANNEL_WEBHOOK_URL',
  ]
end

def valid_environment_variables?
  morph_live_mode? ? required_environment_variables.all? {|var| ENV[var] } : true
end

def main
  unless valid_environment_variables?
    puts "The scraper needs the following environment variables set:"
    puts
    puts required_environment_variables.join("\n")
    exit(1)
  end

  if posted_in_last_fortnight?
    puts 'We have not posted an update during this fortnight.'
    message = build_message

    if morph_live_mode?
      puts 'In live mode'
      puts 'Posting the message to Slack'
      opts = { url: ENV['MORPH_SLACK_CHANNEL_WEBHOOK_URL'] }
      opts[:channel] = '#bottesting' unless morph_live_mode?
      if post_message_to_slack(message,opts) === 'ok'
        # record the message and the date sent to the db
        puts 'Recording the message in the database'
        record = { date_posted: Date.today.to_s, text: message }
        ScraperWiki.save_sqlite([:date_posted], record)
      else
        puts 'Error: could not post the message to Slack!'
      end
    else
      puts 'Not in live mode'
      puts 'Not posting to Slack'
      puts 'Not recording the message in the database'
      puts
      puts message.gsub(/^/m, '> ')
    end
  else
    puts 'We have posted an update during this fortnight.'
  end
end

main() if __FILE__ == $0
