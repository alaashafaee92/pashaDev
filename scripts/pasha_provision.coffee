# Pasha provision-related functionalities
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

bot_name = constant.bot_name
user = constant.http_basic_auth_user
password = constant.http_basic_auth_password
provision_hostname = constant.provision_hostname
provision_port = constant.provision_port
# Helpers
# -------

post_to_provision = (u, pwd, criteria, action) ->
    post_data = "data={\"criteria\": \"#{criteria}\"}"
    https_post_options = {
        hostname: provision_hostname
        auth: "#{u}:#{pwd}"
        port: provision_port
        path: "/#{action}/"
        method: "POST"
        headers: {
            "Content-Type": "application/x-www-form-urlencoded"
            "Content-Length": Buffer.byteLength(post_data)
        }
    }
    req = https.request https_post_options, (res) ->
        data = ''
        res.on 'data', (chunk) ->
            data += chunk.toString()
        res.on 'end', () ->
            scribe_log "changelog response: #{data}"
    timestamp = Math.floor((new Date()).getTime() / 1000)

    req.write(post_data)
    req.end()
    scribe_log "issued #{action} on chef nodes: #{criteria}"

# Commands
# --------

# TODO: Command regexes should be configurable
# runchef
runchef_help = /runchef help$/i
runchef_params = /runchef (.+)/i
# reboot
reboot_help = /reboot help$/i
reboot_params = /reboot (.+)/i

commands =
    runchef: [
        runchef_help,
        runchef_params
    ]
    reboot: [
        reboot_help,
        reboot_params
    ]

# Module exports
# --------------

module.exports = (robot) ->

    register_module_commands(robot, commands)

    robot.respond runchef_help, (msg) ->
        msg.send "#{bot_name} runchef <knife_search_criteria>: " +
            "run chef on the specified nodes"

    robot.respond reboot_help, (msg) ->
        msg.send "#{bot_name} reboot <knife_search_criteria>: " +
            "reboot the specified nodes"

    robot.respond runchef_params, (msg) ->
        try
            criteria = msg.match[1]
            if criteria == 'help'
                return
            post_to_provision(user, password, criteria, "runchef")
            msg.reply msg.random util.ack
        catch error
            scribe_log "ERROR #{error}"

    robot.respond reboot_params, (msg) ->
        try
            criteria = msg.match[1]
            if criteria == 'help'
                return
            post_to_provision(user, password, criteria, "reboot")
            msg.reply msg.random util.ack
        catch error
            scribe_log "ERROR #{error}"

module.exports.commands = commands
