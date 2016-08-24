# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

require 'scraperwiki'
require 'rest-client'
require 'JSON'

# Get the data
planningAlerts_subscribers_data = JSON.parse(
  RestClient.get("https://www.planningalerts.org.au/performance/alerts.json")
)
# build the sentence with new sign up stats
# post it fortnightly

def post_message_to_slack
  request_body = {
    channel: "#bottesting",
    username: "webhookbot",
    text: "This is posted to #bottesting and comes from a bot named webhookbot."
  }

  RestClient.post(ENV["SLACK_CHANNEL_WEBHOOK_URL"], request_body.to_json)
end

