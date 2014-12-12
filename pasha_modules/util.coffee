scribe_log = require('../pasha_modules/scribe_log').scribe_log
https = require('https')
http = require('http')
constant = require('../pasha_modules/constant').constant
State = require('../pasha_modules/model').State
nodemailer = require "nodemailer"
moment = require('moment')

ack = ['roger', 'roger that', 'affirmative', 'ack', 'consider it done', 'done', 'aye captain']

download_users = (token, set_users_callback)->
    scribe_log "downloading users"
    try
        options = {
            hostname: "api.hipchat.com"
            port: 443
            path: "/v1/users/list?format=json&auth_token=#{token}"
            method: "GET"
        }
        https.get options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                users = JSON.parse(data)["users"]
                set_users_callback(users)
                scribe_log "downloaded #{users.length} users"
    catch error
        scribe_log "ERROR " + error
        set_users_callback([])

get_user = (who, my_name, users) ->
    name = who.toLowerCase().replace(/@/g, "").replace(/\s+$/g, "")
    if (name == "me")
        if (not my_name?)
            scribe_log "cannot find 'me' because my_name is not set"
            return null
        name = my_name.toLowerCase().replace(/@/g, "").replace(/\s+$/g, "")
    matched_users = []
    for user in users
        if (user.name.toLowerCase() == name or user.mention_name.toLowerCase() == name)
            scribe_log "user found: #{user.name}"
            return user
        if (user.name.toLowerCase().indexOf(name) != -1 or user.mention_name.toLowerCase().indexOf(name) != -1)
            matched_users.push user
    if (matched_users.length == 1)
        user = matched_users[0]
        scribe_log "user found: #{user.name}"
        return user
    scribe_log "no such user: #{name}"
    return null

get_or_init_state = (adapter) ->
    pasha_state_str = adapter.brain.get(constant.pasha_state_key)
    if (not pasha_state_str? or pasha_state_str.length == 0)
        adapter.brain.set(constant.pasha_state_key, JSON.stringify(new State()))
        pasha_state_str = adapter.brain.get(constant.pasha_state_key)
        scribe_log "state was not found, successfully initialized it"
    pasha_state = JSON.parse(pasha_state_str)
    return pasha_state

update_topic = (token, update_topic_callback, msg, new_topic) ->
    try
        options = {
            hostname: "api.hipchat.com"
            port: 443
            path: "/v1/rooms/list?format=json&auth_token=#{token}"
            method: "GET"
        }
        https.get options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                rooms = JSON.parse(data)["rooms"]
                for room in rooms
                    if room.name == msg.message.room
                        update_topic_callback(msg, room.topic, new_topic)
    catch error
        scribe_log "ERROR " + error

post_to_hipchat = (channel, message) ->
    try
        post_data = "room_id=#{channel}&from=Pasha&message=#{message}&notify=1"
        https_post_options = {
            hostname: "api.hipchat.com"
            port: 443
            path: "/v1/rooms/message?format=json&auth_token=#{constant.hipchat_api_token}"
            method: "POST"
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Content-Length': Buffer.byteLength(post_data)
            }
        }
        req = https.request https_post_options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                scribe_log "hipchat response: #{data}"
        req.write(post_data)
        req.end()
        scribe_log "request sent"
    catch error
        scribe_log "ERROR " + error

generate_prio1_description = (prio1) ->
    return """
        Outage '#{prio1.title}'
        #{generate_prio1_status(prio1)}
    """

generate_prio1_status = (prio1) ->
    detect_time = moment.unix(prio1.time.start)
    confirm_time = moment.unix(prio1.time.confirm)
    return """
        Latest status: #{prio1.status}
        Communication is handled by #{prio1.role.communication}
        Leader is #{prio1.role.leader}
        Detected by #{prio1.role.starter} at #{detect_time.calendar()} - #{detect_time.fromNow()}
        Confirmed by #{prio1.role.confirmer} at #{confirm_time.calendar()} - #{detect_time.fromNow()}
    """

send_status_email = (prio1) ->
    try
        send_email(prio1.title, generate_prio1_status(prio1))
    catch error
        scribe_log "ERROR send_status_email #{error}"

send_confirm_email = (prio1) ->
    try
        send_email(prio1.title, generate_prio1_description(prio1))
    catch error
        scribe_log "ERROR send_confirm_email #{error}"

send_email = (subject, text) ->
    try
        transporter = nodemailer.createTransport()
        transporter.sendMail({
            from: constant.pasha_email_address
            to: constant.outage_email_address
            subject: subject
            text: text
        })
        scribe_log "email sent to #{constant.outage_email_address} with subject: #{subject}"
    catch error
        scribe_log "ERROR " + error

pagerduty_alert = (description) ->
    try
        for service_key in constant.pagerduty_service_keys
            post_data = JSON.stringify({
                service_key: service_key
                event_type: "trigger"
                description: description
            })
            https_post_options = {
                hostname: "events.pagerduty.com"
                port: 443
                path: "/generic/2010-04-15/create_event.json"
                method: "POST"
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(post_data)
                }
            }
            req = https.request https_post_options, (res) ->
                data = ''
                res.on 'data', (chunk) ->
                    data += chunk.toString()
                res.on 'end', () ->
                    scribe_log "pagerduty response: #{data}"
            req.write(post_data)
            req.end()
            scribe_log "pagerduty alert triggered: #{description}"
    catch error
        scribe_log "ERROR " + error


start_nag = (adapter, msg) ->
    state = get_or_init_state(adapter)
    prio1 = state.prio1
    nagger_callback_id = null
    nagger = () ->
        if (not get_or_init_state(adapter).prio1?)
            if (not nagger_callback_id?)
                scribe_log "nagger callback shouldn't be called but it was"
                return
            clearInterval nagger_callback_id
            scribe_log "stopped nagging #{prio1.title}"
            return
        try
            nag_target = if prio1.role.comm then prio1.role.comm else prio1.role.starter
            msg.send "@#{get_user(nag_target, null, state.users).mention_name}, please use '#{constant.bot_name} status <some status update>' regularly, the last status update for the current outage was at #{moment.unix(prio1.time.last_status).fromNow()}"
        catch error
            scribe_log "ERROR nagger #{error}"
    nagger_callback_id = setInterval(nagger, 10 * 60 * 1000)

module.exports = {
    get_user: get_user
    download_users: download_users
    get_or_init_state: get_or_init_state
    ack: ack
    update_topic: update_topic
    post_to_hipchat: post_to_hipchat
    send_email: send_email
    send_confirm_email: send_confirm_email
    send_status_email: send_status_email
    pagerduty_alert: pagerduty_alert
    start_nag: start_nag
}
