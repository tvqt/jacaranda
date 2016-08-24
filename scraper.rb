# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

require 'scraperwiki'
require 'rest-client'
require 'JSON'
require "active_support/all"

def post_message_to_slack(text)
  request_body = {
    channel: "#bottesting",
    username: "webhookbot",
    text: text
  }

  RestClient.post(ENV["SLACK_CHANNEL_WEBHOOK_URL"], request_body.to_json)
end

# Get the data
planningalerts_subscribers_data = JSON.parse(
  RestClient.get("https://www.planningalerts.org.au/performance/alerts.json")
)

beginning_of_fortnight = 1.fortnight.ago.beginning_of_week.to_date
end_of_fortnight = 1.week.ago.end_of_week.to_date
last_fortnight = (beginning_of_fortnight..end_of_fortnight).to_a

new_signups_last_fortnight = 0

last_fortnight.each do |date|
  planningalerts_subscribers_data.each do |row|
    if row["date"].eql? date.to_s
      new_signups_last_fortnight += row["new_alert_subscribers"]
    end
  end
end

# build the sentence with new sign up stats
text = new_signups_last_fortnight.to_s +
       " people signed up for PlanningAlerts last fortnight."

# if it's been a fortnight since the last message post a new one
if (ScraperWiki.select("* from data where `date_posted`>'#{1.fortnight.ago.to_date.to_s}'").empty? rescue true)
  if post_message_to_slack(text) === "ok"
    # record the message and the date sent to the db
    ScraperWiki.save_sqlite([:date_posted], {date_posted: Date.today.to_s, text: text})
  end
end
