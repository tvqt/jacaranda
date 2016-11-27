# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

require 'octokit'
require 'scraperwiki'
require 'mechanize'
require 'rest-client'
require 'json'
require "active_support/all"

def post_message_to_slack(text)
  request_body = {
    username: "Jacaranda",
    text: text
  }

  request_body.merge!(channel: "#bottesting") unless ENV["MORPH_LIVE_MODE"].eql? "true"

  RestClient.post(ENV["MORPH_SLACK_CHANNEL_WEBHOOK_URL"], request_body.to_json)
end

def git_commits_between_dates(start_date, end_date)
  github_client = Octokit::Client.new :access_token => ENV["MORPH_GITHUB_OAUTH_ACCESS_TOKEN"]
  response = github_client.get(
    "repos/openaustralia/planningalerts/commits?since=#{start_date.to_s}&until#{end_date.to_s}"
  )

  commits_count = response.count

  last_response = github_client.last_response
  until last_response.rels[:next].nil?
    last_response = last_response.rels[:next].get
    commits_count += last_response.data.count
  end

  commits_count
end

def planningalerts_subscribers_data
  # Get the data
  @planningalerts_subscribers_data ||= JSON.parse(
    RestClient.get("https://www.planningalerts.org.au/performance/alerts.json")
  )
end

def get_planningalerts_data_between(attribute, start_date, end_date)
  new_signups_for_period = 0

  period = (start_date..end_date).to_a
  period.each do |date|
    planningalerts_subscribers_data.each do |row|
      if row["date"].eql? date.to_s
        new_signups_for_period += row[attribute]
      end
    end
  end

  new_signups_for_period
end

def get_total_subscriber_count
  page = Mechanize.new.get("https://www.planningalerts.org.au/performance")
  page.at('#content h2').text.split(" ").first.to_i
end

class Numeric
  def percent_of(n)
    self.to_f / n.to_f * 100.0
  end
end

def percentage_change_in_words(change)
  text = change.to_s.delete("-") + "% "
  text += change > 0 ? "more" : "less"
  text
end

def change_sentence(last_fortnight, fortnight_before_last)
  percentage_change_from_fortnight_before = last_fortnight.percent_of(fortnight_before_last)- 100
  percentage_change_from_fortnight_before = percentage_change_from_fortnight_before.round(1).floor

  change_sentence = "That’s " + percentage_change_in_words(percentage_change_from_fortnight_before) + " than the fortnight before."
end

beginning_of_fortnight = 1.fortnight.ago.beginning_of_week.to_date
end_of_fortnight = 1.week.ago.end_of_week.to_date
last_fortnight = (beginning_of_fortnight..end_of_fortnight).to_a

beginning_of_fortnight_before_last = 2.fortnight.ago.beginning_of_week.to_date
end_of_fortnight_before_last = 3.weeks.ago.end_of_week.to_date
fortnight_before_last = (beginning_of_fortnight_before_last..end_of_fortnight_before_last)

# if it's been a fortnight since the last message post a new one
if ENV["MORPH_LIVE_MODE"].eql? "true"
  puts "In live mode, this will post to Slack and save to the db"
else
  puts "In test mode, this wont post to Slack or save to the db"
end

puts "Check if it has collected data in the last fortnight"
if (ScraperWiki.select("* from data where `date_posted`>'#{1.fortnight.ago.to_date.to_s}'").empty? rescue true)
  puts "Collect information from GitHub"
  commits_count = git_commits_between_dates(last_fortnight.first, last_fortnight.last)

  puts "Collect total subscribers information from PlanningAlerts"
  total_planningalerts_subscribers = get_total_subscriber_count

  puts "Collect new subscriber/unsubscriber information from PlanningAlerts"
  new_signups_last_fortnight = get_planningalerts_data_between("new_alert_subscribers", last_fortnight.first, last_fortnight.last)
  new_signups_fortnight_before_last = get_planningalerts_data_between("new_alert_subscribers", fortnight_before_last.first, fortnight_before_last.last)

  unsubscribers_last_fortnight = get_planningalerts_data_between("emails_completely_unsubscribed", last_fortnight.first, last_fortnight.last)
  unsubscribers_fortnight_before_last = get_planningalerts_data_between("emails_completely_unsubscribed", fortnight_before_last.first, fortnight_before_last.last)

  # build the sentence with new sign up stats
  text = new_signups_last_fortnight.to_s +
        " people signed up for PlanningAlerts last fortnight :revolving_hearts:"
  text += " " + change_sentence(new_signups_last_fortnight, new_signups_fortnight_before_last) + "\n"
  text += unsubscribers_last_fortnight.to_s + " people left. "
  text += change_sentence(unsubscribers_last_fortnight, unsubscribers_fortnight_before_last) + "\n"
  text += "You shipped #{commits_count} commits in the same period.\n" unless commits_count.zero?
  text += "There are now " + ActiveSupport::NumberHelper.number_to_human(total_planningalerts_subscribers).downcase +
          " PlanningAlerts subscribers! :star2:"

  puts "Post the message to Slack"
  if post_message_to_slack(text) === "ok"
    # record the message and the date sent to the db
    puts "Save the message to the db"

    if ENV["MORPH_LIVE_MODE"].eql? "true"
      ScraperWiki.save_sqlite([:date_posted], {date_posted: Date.today.to_s, text: text})
    else
      puts text
    end
  end
else
  p "I’ve already spoken to the team this fortnight"
end
