# Jacaranda

*A watchful tree and Slack messenger to keep you informed of the use of PlanningAlerts.*

Working on PlanningAlerts over the last year we’ve noticed that:

* We don’t have an accurate idea of the impact of PlanningAlerts, how many people are using it, or the rate a which this is changing; and
* We feel more energised in our work when we get feedback about it’s use and impact.

Jacaranda is an experiment to see the impact of regular feedback on the people developing PlanningAlerts. It aims to keep you more informed of the use and impact of PlanningAlerts; to remind you of the effort you’ve put in to achieve this; and to do this in an quick and unobtrusive way.

Jacaranda collects information about people using PlanningAlerts and the work we do to make it better for them. It then sends a short fortnightly message to our Slack channel to give us a sense of how things are going.

![Image of slack message from Jacaranda](screenshot.jpg)

This is a very basic start. We’ve interested to see how getting these messages impacts us and what we do with the information.

Currently Jacaranda tells you about:

* the number of people who signed up for PlanningAlerts in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of people who have unsubscribed in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of commits pushed to the project in the last fortnight; and,
* the total number of people now signed up to PlanningAlerts.

While the number of users isn’t a great measure of PlanningAlerts’ impact, it’s a start to see how the feedback works for us. Feel free to change the text or the information in presents to what you think will have a better impact.

### Caveats

The time frames that this claims to show subscribers for aren’t accurate because they're displayed as it they were recorded in local time, but they're actually counted in UTC.

## Quickstart

Ensure you have Ruby + Bundler installed, then run:

``` bash
git clone https://github.com/openaustralia/jacaranda.git
cd jacaranda
bundle
```

Then run the scraper with:

``` bash
bundle exec ruby scraper.rb
```

And run the tests with:

``` bash
bundle exec rspec
```

## Usage

This scraper requires three environment variables:

* `MORPH_GITHUB_OAUTH_ACCESS_TOKEN` to talk to the GitHub API. You must generate a [personal access token](https://github.com/settings/tokens) with the `repo` permission.
* `MORPH_SLACK_CHANNEL_WEBHOOK_URL` to post the message to a channel in Slack. You can get a URL by adding an _Incoming Webhook_ customer integration in your Slack org.
* `MORPH_LIVE_MODE` determines if the scraper actually posts to the Slack channel `#townsquare` and save to the database

When developing locally, you can add these environment variables to a [`.env` file](https://github.com/bkeepers/dotenv) so the scraper loads them when it runs:

``` bash
MORPH_SLACK_CHANNEL_WEBHOOK_URL="https://hooks.slack.com/services/XXXXXXXXXXXXX"
MORPH_GITHUB_OAUTH_ACCESS_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
MORPH_LIVE_MODE=false
```

Create a `.env` file using the supplied example by running:

```
cp .env.example .env
```

Then edit to taste.

### Running the scraper on morph.io

You can also run this as a scraper on [Morph](https://morph.io).

To get started [see the documentation](https://morph.io/documentation)

## Image credit

The Jacaranda Slack avatar is cropped from a [photograph of the Jacaranda trees on Gowrie St, Newtown, Sydney by Flickr user murry](https://www.flickr.com/photos/hopeless128/15808564051/in/photolist-aCSCXw-q8S). Thanks murry for making it available under a creative commons license.
