module.exports = {
    constant: {
        bot_name: process.env.BOT_NAME

        pasha_state_key: 'PASHA_STATE'

        hipchat_api_token: process.env.HIPCHAT_API_TOKEN
        hipchat_relay_rooms: (process.env.HIPCHAT_RELAY_ROOMS).split(",").filter (x) -> x.trim().length > 0
        hipchat_message_limit: 10000
        hangout_url: process.env.HANGOUT_URL

        http_basic_auth_user: process.env.HTTP_BASIC_AUTH_USER
        http_basic_auth_password: process.env.HTTP_BASIC_AUTH_PASSWORD

        pasha_email_address: process.env.PASHA_EMAIL_ADDRESS
        outage_email_address: process.env.OUTAGE_EMAIL_ADDRESS

        changelog_hostname: process.env.CHANGELOG_HOST_NAME
        changelog_port: process.env.CHANGELOG_PORT

        pagerduty_api_key: process.env.PAGERDUTY_SERVICE_API_KEY
        pagerduty_hostname: process.env.PAGERDUTY_HOST_NAME
        pagerduty_port: process.env.PAGERDUTY_PORT
        pagerduty_service_keys: (process.env.PAGERDUTY_SERVICE_KEYS).split(",")
            .filter (x) -> x.trim().length > 0

        provision_hostname: process.env.PROVISION_HOST_NAME
        provision_port: process.env.PROVISION_PORT

        playbook_url: process.env.PRIO1_PLAYBOOK_URL
        prio1_monitored_website: process.env.PRIO1_MONITORED_WEBSITE
    }
}
