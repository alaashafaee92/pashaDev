# Pasha changelog-related functionalities
# ---------------------------------------

# Node imports
https = require('https')
# Pasha imports
scribe_log = require('../pasha_modules/scribe_log').scribe_log
constant = require('../pasha_modules/constant').constant
State = require('../pasha_modules/model').State
util = require('../pasha_modules/util')
register_module_commands =
    require('../scripts/commands').register_module_commands

MSG_MAX = constant.hipchat_message_limit
bot_name = constant.bot_name
user = constant.http_basic_auth_user
password = constant.http_basic_auth_password
changelog_hostname = constant.changelog_hostname
changelog_port = constant.changelog_port

# Helpers
# -------

post_to_changelog = (u, pwd, change) ->
    https_post_options = {
        hostname: changelog_hostname
        auth: "#{u}:#{pwd}"
        port: changelog_port
        path: "/api/events"
        method: "POST"
        headers: { "Content-Type": "application/json" }
    }
    req = https.request https_post_options, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            scribe_log "changelog response: #{data}"
    timestamp = Math.floor((new Date()).getTime() / 1000)
    post_data = "{\"criticality\": 1, \"unix_timestamp\": #{timestamp}, " +
        "\"category\": \"pasha\", \"description\": \"#{change}\"}"
    req.write(post_data)
    req.end()
    scribe_log "added to changelog: #{change}"

get_data_from_changelog = (u, pwd, hours, process_events_callback) ->
    https_get_options = {
        hostname: changelog_hostname
        auth: "#{u}:#{password}"
        port: changelog_port
        path: "/api/events?hours_ago=#{hours}&until=-1"
        method: "GET"
    }
    https.get https_get_options, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            events = JSON.parse(data)
            events.sort (a, b) ->
                return if a.unix_timestamp <= b.unix_timestamp then 1 else -1
            process_events_callback(events)

splitMessages = (message) ->
    current_pos = 0
    end_pos = MSG_MAX
    split_messages = []
    while current_pos < message.length - 1
        split_messages.push message.slice current_pos, end_pos
        current_pos = end_pos
        end_pos = current_pos + MSG_MAX
    return split_messages

# Commands
# --------

# TODO: Command regexes should be configurable
changelog_add_params = /changelog add (.+)/i
changelog_addsilent_params = /changelog addsilent (.+)/i
changelog_params = /changelog -?(\d+)([smhd])( -f)?$/i
changelog_help_from_main = /changelog help_from_main$/i
changelog_help = /changelog help$/i

commands =
    changelog: [
        changelog_add_params,
        changelog_addsilent_params,
        changelog_params,
        changelog_help_from_main,
        changelog_help
    ]

# Module exports
# --------------

module.exports = (robot) ->

    register_module_commands(robot, commands)

    robot.respond changelog_add_params, (msg) ->
        try
            change = msg.match[1].replace(/\"/g, "'")
            change = "#{msg.message.user.name}: #{change}"
            post_to_changelog(user, password, change)
            msg.reply msg.random util.ack
        catch error
            scribe_log "ERROR #{error}"

    robot.respond changelog_addsilent_params, (msg) ->
        try
            change = msg.match[1].replace(/\"/g, "'")
            post_to_changelog(user, password, change)
        catch error
            scribe_log "ERROR #{error}"

    robot.respond changelog_params, (msg) ->
        try
            number = parseInt(msg.match[1], 10)
            unit = msg.match[2]
            now_ts = Math.floor((new Date()).getTime() / 1000)
            unit_multiplier = switch unit
                when 's' then 1
                when 'm' then 60
                when 'h' then 3600
                when 'd' then 86400
            ts_difference = number * unit_multiplier
            from_ts = now_ts - ts_difference
            difference_hours = Math.ceil(ts_difference / 3600)
            force_printing = (msg.match[3] == ' -f')
            print_events = (events) ->
                resp = ""
                for e in events.reverse()
                    if (e.unix_timestamp >= from_ts)
                        d = new Date(e.unix_timestamp * 1000)
                        resp += "#{d.toISOString()} - #{e.category} - " +
                            "#{e.description}\n"
                if resp.length == 0
                    msg.send 'No entries to show'
                else if !force_printing
                    if resp.length > MSG_MAX
                        msg.send 'Too many entries to show\n' +
                            'Add -f to get the entries in seperate messages'
                    else
                        msg.send resp
                else if force_printing
                    split_msg = splitMessages(resp)
                    for m in split_msg
                        msg.send m
                scribe_log "queried #{events.length} events from changelog"
            get_data_from_changelog(user, password, difference_hours,
                print_events)
        catch error
            scribe_log "ERROR #{error}"

    robot.respond changelog_help_from_main, (msg) ->
        msg.send "#{bot_name} changelog <subcommand>: manage changelog, " +
            "see '#{bot_name} changelog help' for details"

    robot.respond changelog_help, (msg) ->
        msg.send "#{bot_name} changelog add <event>: add event to changelog\n" +
            "#{bot_name} changelog <int>[smhd]: " +
            "list recent changelog events for the specified time interval"

module.exports.splitMessages = splitMessages
module.exports.commands = commands
