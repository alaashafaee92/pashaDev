#!/bin/bash -ex

# set default values for env vars
BOT_NAME=pasha

HUBOT_HIPCHAT_JID=
HUBOT_HIPCHAT_PASSWORD=
HUBOT_HIPCHAT_ROOMS=

HIPCHAT_API_TOKEN=
HIPCHAT_RELAY_ROOMS=

HANGOUT_URL=

REDIS_ADDRESS=localhost
REDIS_PORT=6379

SCRIBE_SERVER_ADDRESS=$(/sbin/ip route | awk '/default/ { print $3 }')
SCRIBE_SERVER_PORT=1463

HTTP_BASIC_AUTH_USER=
HTTP_BASIC_AUTH_PASSWORD=

PASHA_EMAIL_ADDRESS=
OUTAGE_EMAIL_ADDRESS=

PAGERDUTY_SERVICE_KEYS=
CONFIG_PATH=

# load env vars from the config file
if [ -f $CONFIG_PATH ]
then
    . $CONFIG_PATH
fi

# export env vars
export BOT_NAME

export HUBOT_HIPCHAT_JID
export HUBOT_HIPCHAT_PASSWORD
export HUBOT_HIPCHAT_ROOMS

export HIPCHAT_API_TOKEN
export HIPCHAT_RELAY_ROOMS

export HANGOUT_URL

export REDIS_URL=redis://$REDIS_ADDRESS:$REDIS_PORT

export SCRIBE_SERVER_ADDRESS
export SCRIBE_SERVER_PORT

export HTTP_BASIC_AUTH_USER
export HTTP_BASIC_AUTH_PASSWORD

export PASHA_EMAIL_ADDRESS
export OUTAGE_EMAIL_ADDRESS

export PAGERDUTY_SERVICE_KEYS
export PAGERDUTY_SERVICE_API_KEY

# start hubot
$(dirname $0)/../bin/hubot --adapter hipchat