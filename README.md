# Jacaranda

*A watchful tree and slack messenger to keep you informed of the use of PlanningAlerts.*

Working on PlanningAlerts over the last year we’ve noticed that:

* We don’t have an accurate idea of the impact of PlanningAlerts,
  how many people are using it,
  or the rate a which this is changing; and
* We feel more energised in our work when we get feedback about it’s use and
  impact.

Jacaranda is an experiment to see the impact of regular feedback
on the people developing PlanningAlerts.
It aims to keep you more informed of the use and impact of PlanningAlerts;
to remind you of the effort you’ve put in to achieve this; and to do this in an
quick and unobtrusive way.

Jacaranda collects information about people using PlanningAlerts and
the work we do to make it better for them.
It then sends a short fortnightly message to our Slack channel
to give us a sense of how things are going.

![Image of slack message from Jacaranda](screenshot.jpg)

This is a very basic start.
We’ve interested to see how getting these messages impacts us
and what we do with the information.

Currently Jacaranda tells you about:

* the number of people who signed up for PlanningAlerts in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of people who have unsubscribed in the last fortnight;
* the difference between this number and the figure for the previous fortnight;
* the number of commits pushed to the project in the last fortnight; and,
* the total number of people now signed up to PlanningAlerts.

While the number of users isn’t a great measure of PlanningAlerts’ impact,
it’s a start to see how the feedback works for us.
Feel free to change the text or the information in presents to what you think
will have a better impact.

### Caveats

PlanningAlerts currently provide data about
the number of *currently active subscribers who signed up in the last fortnight*.
This means that if people subscribe and unsubscribe within a fortnight,
they won’t be counted.

The time frames that this claims to show subscribers for aren’t accurate
because they're displayed as it they were recorded in local time, but they're
actually counted in UTC.

## Usage

This program depends on two environment variables:

* *GitHub OAuth token* for your github account
* *Slack channel webhook url* to post the message to

In local development you can add these to a `.env` file
and [use dotenv](https://github.com/bkeepers/dotenv) to load them as the scraper runs:

```
MORPH_SLACK_CHANNEL_WEBHOOK_URL="https://hooks.slack.com/services/XXXXXXXXXXXXX"
MORPH_GITHUB_OAUTH_ACCESS_TOKEN=XXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

Create a `.env` file using the example provided by running `cp .env.example .env`.

### Running this on morph.io

You can also run this as a scraper on [Morph](https://morph.io).
To get started [see the documentation](https://morph.io/documentation)

## Image credit

The Jacaranda Slack avatar is cropped from a [photograph of the Jacaranda trees on
Gowrie St, Newtown, Sydney by Flickr user
murry](https://www.flickr.com/photos/hopeless128/15808564051/in/photolist-aCSCXw-q8S).
Thanks murry for making it available under a creative commons license.
