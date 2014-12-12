# Pasha prio1 related functionalities
# -----------------------------------

# Hubot imports
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
scribe_log = require('../pasha_modules/scribe_log').scribe_log
Prio1 = require('../pasha_modules/model').Prio1
State = require('../pasha_modules/model').State
Channel =  require('../pasha_modules/model').Channel
constant = require('../pasha_modules/constant').constant
util = require('../pasha_modules/util')
register_module_commands =
    require('../scripts/commands').register_module_commands

bot_name = constant.bot_name

playbook_url = constant.playbook_url
playbook_info = "I recommend to follow the steps in:\n" +
                "Prio1 Playbook URL = #{playbook_url}"
prio1_monitored_website = constant.prio1_monitored_website

#Commands

#TODO: Command regexes should be configurable
# prio1
prio1_help = /prio1$|prio1 help$/i
prio1_start = /prio1 start$/i
prio1_start_parameters = /prio1 start (.+)/i
prio1_confirm = /prio1 confirm$/i
prio1_stop = /prio1 stop$/i
role_help = /role$|role help$/i
# role
role_comm = /role comm$/i
role_comm_parameters = /role comm (.+)/i
role_leader = /role leader$/i
role_leader_parameters = /role leader (.+)/i
# status
status_help = /status help$/i
status_parameters = /status (.+)/i
status_core = /status$/i
# say
say = /say (.+)/i
# whois
whois = /whois (.+)/i
# help
help = /$| help$/i
# healthcheck
healthcheck_core = /healthcheck/i

commands =
    prio1: [
        prio1_help,
        prio1_start,
        prio1_start_parameters,
        prio1_confirm,
        prio1_stop
    ]
    role: [
        role_help,
        role_comm,
        role_comm_parameters,
        role_leader,
        role_leader_parameters
    ]
    status: [
        status_help,
        status_core,
        status_parameters
    ]
    say: [say]
    whois: [whois]
    help: [help]
    healthcheck: [healthcheck_core]

module.exports = (robot) ->

    register_module_commands(robot, commands)

    set_users = (users) ->
        pasha_state = util.get_or_init_state(robot)
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        scribe_log "set #{users.length} users"

    try
        scribe_log 'initializing prio1 module'
        hipchat_api_token_exists = constant.hipchat_api_token? and
            constant.hipchat_api_token.length != 0
        if (hipchat_api_token_exists)
            util.download_users(constant.hipchat_api_token, set_users)
    catch error
        scribe_log "ERROR #{error}"

    relay = (message) ->
        scribe_log "relaying: #{message}"
        try
            for room in constant.hipchat_relay_rooms
                util.post_to_hipchat(room, message)
                scribe_log "sending #{message} to #{room}"
        catch error
            scribe_log "ERROR #{error}"

    robot.respond say, (msg) ->
        try
            msg.send msg.match[1]
        catch error
            scribe_log "ERROR #{error}"

    robot.respond whois, (msg) ->
        try
            pasha_state = util.get_or_init_state(robot)
            who = msg.match[1]
            u = util.get_user(who, msg.message.user.name, pasha_state.users)
            if (not u?)
                msg.reply "no such user: #{who}"
            else
                msg.send "Full Name: #{u.name}\n" +
                         "Title: #{u.title}"
        catch error
            scribe_log "ERROR #{error}"

    robot.respond help, (msg) ->
        msg.send "#{bot_name} prio1 <subcommand>: " +
            "manage prio1, see '#{bot_name} prio1 help' for details\n" +
            "#{bot_name} role <role> <name>: assign prio1 roles to people, " +
            "see '#{bot_name} role help' for details\n" +
            "#{bot_name} status: display or set prio1 status, " +
            "see '#{bot_name} status help' for details"
        robot.receive(new TextMessage(msg.message.user,
            "#{bot_name} changelog help_from_main"))
        robot.receive(new TextMessage(msg.message.user,
            "#{bot_name} runchef help"))
        robot.receive(new TextMessage(msg.message.user,
            "#{bot_name} reboot help"))
        robot.receive(new TextMessage(msg.message.user,
            "#{bot_name} alert help_from_main"))
        robot.receive(new TextMessage(msg.message.user,
            "#{bot_name} graph help_from_main"))

    
    robot.respond prio1_help, (msg) ->
        response = "#{bot_name} prio1 start <problem>: initiate prio1 mode\n" +
            "#{bot_name} prio1 confirm: confirm prio1\n" +
            "#{bot_name} prio1 stop: stop prio1"
            if (playbook_url? and playbook_url.length > 0)
                response += "\n#{playbook_info}"
            msg.send response

    robot.respond prio1_start, (msg) ->
        response =  "#{bot_name} prio1 start <problem>: initiate prio1 mode"
        if (playbook_url? and playbook_url.length > 0)
            response += "\n#{playbook_info}"
        msg.send response

    robot.respond prio1_start_parameters, (msg) ->
        try
            status = msg.match[1]
            scribe_log "starting prio1: #{status}"
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (prio1?)
                response = 'cannot start a prio1: ' +
                    'there is one currently going on'
                scribe_log response
                msg.reply "you #{response}"
                return
            user = msg.message.user.name
            timestamp = Math.floor((new Date()).getTime() / 1000)
            prio1 = new Prio1(user, timestamp, status)
            pasha_state.prio1 = prio1
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            response = "#{user} started the prio1: #{status}\n" +
                "you can confirm the prio1 with '#{bot_name} prio1 confirm'"
            if (playbook_url? and playbook_url.length > 0)
                response += "\n#{playbook_info}"
            msg.send response
            relay "#{user} started a prio1: #{status}. " +
                    "you can confirm it by joining the 'Ops' room and saying " +
                    "'#{bot_name} prio1 confirm'"
            scribe_log "started prio1: #{status}"
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{user} started the prio1: " +
                "#{status}"))
            util.start_nag robot, msg
        catch error
            scribe_log "ERROR #{error}"

    update_topic_callback = (msg, old_topic, new_topic) ->
        try
            pasha_state = util.get_or_init_state(robot)
            pasha_state.prio1.channel[msg.message.room] =
                new Channel(old_topic)
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            scribe_log "saved old channel topic: #{old_topic}"
            msg.topic new_topic
            scribe_log "set new topic: #{new_topic}"
        catch error
            scribe_log "ERROR #{error}"

    robot.respond prio1_confirm, (msg) ->
        try
            scribe_log "confirming prio1"
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                response = 'cannot confirm the prio1: ' +
                    'there is no prio1 going on'
                scribe_log response
                msg.reply "you #{response}"
                return
            if (prio1.role.confirmer?)
                response = 'the prio1 already is confirmed'
                scribe_log response
                msg.reply response
                return
            user = msg.message.user.name
            pasha_state.prio1.role.confirmer = user
            timestamp = Math.floor((new Date()).getTime() / 1000)
            pasha_state.prio1.time.confirm = timestamp
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            new_topic = 'PRIO1_MODE=ON'
            if (constant.hangout_url? and constant.hangout_url.length != 0)
                new_topic += " | hangout url: #{constant.hangout_url}"
                msg.send "hangout url: #{constant.hangout_url}"
            util.update_topic(constant.hipchat_api_token,
                update_topic_callback, msg, new_topic)
            msg.send "#{user} confirmed the prio1\n" +
                "the leader of the prio1 is #{pasha_state.prio1.role.leader}" +
                ", you can change it with '#{bot_name} role leader <name>'"
            relay "#{user} confirmed the prio1"
            util.send_confirm_email(prio1)
            util.pagerduty_alert("outage: #{pasha_state.prio1.title}")
            scribe_log "confirmed prio1"
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{user} confirmed the prio1"))
        catch error
            scribe_log "ERROR #{error}"

    robot.respond prio1_stop, (msg) ->
        try
            scribe_log "stopping prio1"
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                response = 'cannot stop the prio1: ' +
                    'there is no prio1 going on'
                scribe_log response
                msg.reply "you #{response}"
                return
            user = msg.message.user.name
            response = "#{user} stopped the prio1: #{prio1.title}"
            msg.send response
            relay response
            start_time = (new Date(prio1.time.start * 1000)).toISOString()
            confirm_time = (new Date(prio1.time.confirm * 1000)).toISOString()
            end_time = (new Date()).toISOString()
            util.send_email(prio1.title, "Outage over.")
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{user} stopped the prio1: " +
                "#{prio1.title}"))
            room_has_old_topic = pasha_state.prio1? and
                pasha_state.prio1.channel[msg.message.room]?
            if (room_has_old_topic)
                old_topic =
                    pasha_state.prio1.channel[msg.message.room].saved_topic
                msg.topic old_topic
            pasha_state.prio1 = null
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            scribe_log 'stopped prio1'
        catch error
            scribe_log "ERROR #{error}"

    robot.respond role_help, (msg) ->
        msg.send "#{bot_name} role leader <name>: " +
            "assign prio1 leader role to a person\n" +
            "#{bot_name} role comm <name>: " +
            "assign prio1 communication officer role to a person"

    robot.respond role_comm, (msg) ->
        msg.send "#{bot_name} role comm <name>: " +
            "assign prio1 communication officer role to a person"

    robot.respond role_comm_parameters, (msg) ->
        try
            who = msg.match[1]
            scribe_log "setting comm role to: #{who}"
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                response = 'cannot set the comm role: ' +
                    'there is no prio1 going on'
                scribe_log response
                msg.reply "you #{response}"
                return
            user = util.get_user(who, msg.message.user.name, pasha_state.users)
            if (not user?)
                response = "no such user: #{who}"
                scribe_log response
                msg.reply response
                return
            name = user.name
            pasha_state.prio1.role.comm = name
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            msg.send "comm role is now assigned to #{name}, " +
                "you can change it with '#{bot_name} role comm <name>'"
            scribe_log "#{msg.message.user.name} assigned comm role to #{name}"
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{msg.message.user.name} " +
                "assigned comm role to #{name}"))
        catch error
            scribe_log "ERROR #{error}"

    robot.respond role_leader, (msg) ->
        msg.send "#{bot_name} role leader <name>: " +
            "assign prio1 leader role to a person"

    robot.respond role_leader_parameters, (msg) ->
        try
            who = msg.match[1]
            scribe_log "setting leader role to: #{who}"
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                msg.reply 'you cannot set the leader role: ' +
                    'there is no prio1 going on'
                return
            user = util.get_user(who, msg.message.user.name, pasha_state.users)
            if (not user?)
                response = "no such user: #{who}"
                scribe_log response
                msg.reply response
                return
            name = user.name
            pasha_state.prio1.role.leader = name
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            msg.send "leader role is now assigned to #{name}, " +
                "you can change it with '#{bot_name} role leader <name>'"
            scribe_log "#{msg.message.user.name} assigned leader role to " +
                "#{name}"
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{msg.message.user.name}" +
                " assigned leader role to #{name}"))
        catch error
            scribe_log "ERROR #{error}"

    robot.respond status_help, (msg) ->
        msg.send "#{bot_name} status: " +
            "display the status of the ongoing prio1\n" +
            "#{bot_name} status <status>: set status of the ongoing prio1"

    robot.respond status_core, (msg) ->
        try
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                response = 'cannot display prio1 status: ' +
                    'there is no prio1 going on'
                scribe_log response
                msg.reply response
                return
            start_time = (new Date(prio1.time.start * 1000)).toISOString()
            confirm_time = null
            if (prio1.time.confirm?)
                confirm_time =
                    (new Date(prio1.time.confirm * 1000)).toISOString()
            msg.send "Prio1 status: #{prio1.status}\n" +
                "Started: #{prio1.role.starter} at #{start_time}\n" +
                "Confirmed: #{prio1.role.confirmer} at #{confirm_time}\n" +
                "Leader: #{prio1.role.leader}\n" +
                "Communication: #{prio1.role.comm}"
            scribe_log "#{msg.message.user.name} displayed status"
        catch error
            scribe_log "ERROR #{error}"

    robot.respond status_parameters, (msg) ->
        try
            status = msg.match[1]
            pasha_state = util.get_or_init_state(robot)
            prio1 = pasha_state.prio1
            if (not prio1?)
                response = 'cannot set prio1 status: ' +
                    'there is no prio1 going on'
                scribe_log response
                msg.reply response
                return
            pasha_state.prio1.status = status
            pasha_state.prio1.time.last_status = new Date()
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))
            msg.reply msg.random util.ack
            response = "#{msg.message.user.name} set status to #{status}"
            relay response
            util.send_status_email(prio1)
            scribe_log response
            robot.receive(new TextMessage(msg.message.user,
                "#{bot_name} changelog addsilent #{msg.message.user.name} " +
                "set status to #{status}"))
        catch error
            scribe_log "ERROR #{error}"

    robot.respond /healthcheck/i, (msg) ->
        msg.reply 'hello'

    prio1_synonyms =
        ['prio1', 'prio 1', 'outage']
    if(prio1_monitored_website? and prio1_monitored_website.length > 0)
        prio1_synonyms.push("#{prio1_monitored_website} is down")
    prio1_synonyms_string = prio1_synonyms.join('|')
    prio1_detector_regex =
        new RegExp("^(?!#{bot_name})(.* )?(#{prio1_synonyms_string}).*$", "i")
    robot.hear prio1_detector_regex, (msg) ->
        pasha_state = util.get_or_init_state(robot)
        prio1 = pasha_state.prio1
        if (not prio1?)
            response = 'Is there a prio1? If yes, please register it ' +
                   'with "pasha prio1 start <description of the issue>"'
            msg.send response

# Export commands to make it testable
module.exports.commands = commands
