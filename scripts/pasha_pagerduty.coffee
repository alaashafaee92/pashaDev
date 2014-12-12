# Description
#   Alerts pagerduty services by specifying service names.
#   Lists the active incidents on Pagerduty.
#
# Dependencies
#   None
#
# Configuration
#   PAGERDUTY_SERVICE_KEYS
#   PAGERDUTY_SERVICE_API_KEY
#
# Commands:
#   <bot name> alert trigger <service_name> <alert_description>:
#       triggers an alert to the specified service
#   <bot name> alert list:
#       lists the details of the active Pagerduty alerts
#   <bot_name> alert help:
#        responds with a description for alert subcommands

# Node imports
https = require('https')
http = require('http')
# Pasha imports
scribe_log = require('../pasha_modules/scribe_log').scribe_log
constant = require('../pasha_modules/constant').constant
register_module_commands =
    require('../scripts/commands').register_module_commands

bot_name = constant.bot_name
pagerduty_api_key = constant.pagerduty_api_key
pagerduty_hostname = constant.pagerduty_hostname
pagerduty_port = constant.pagerduty_port
service_name_key = {}

# Helpers
# -------

#stores the mappings of service names and their keys in 'service_name_key' json
service_name_key_mapping = () ->
    auth = "Token token=#{pagerduty_api_key}"

    try
        https_get_options = {
            hostname: pagerduty_hostname
            port: pagerduty_port
            path: "/api/v1/services"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
            }
        }

        req = https.request https_get_options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                services = JSON.parse(data)["services"]
                for service in services
                    service_name_key[service.name] = service.service_key
        req.end()
        scribe_log "Initialized the mappings between services names and keys"
    catch error
        scribe_log "ERROR #{error}"

#triggers an alert to a service given its service_key
pagerduty_alert_service = (msg, description, service_key) ->
    try
        post_data = JSON.stringify({
            service_key: service_key
            event_type: "trigger"
            description: description
        })

        https_post_options = {
            hostname: "events.pagerduty.com"
            port: pagerduty_port
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
        msg.reply "pagerduty alert triggered: #{description}"
    catch error
        scribe_log "ERROR #{error}"

#replies to 'msg' with the details of all active pagerduty incidents
get_active_incidents = (msg) ->
    auth = "Token token=#{pagerduty_api_key}"
    try
        https_get_options = {
            hostname: pagerduty_hostname
            port: pagerduty_port
            path: "/api/v1/incidents/?status=triggered,acknowledged"
            method: "GET"
            headers: {
                'Authorization': auth
                'Content-Type': 'application/json'
            }
        }

        req = https.request https_get_options, (res) ->
            data = ''
            res.on 'data', (chunk) ->
                data += chunk.toString()
            res.on 'end', () ->
                data_json = JSON.parse(data)
                incidents = data_json["incidents"]
                incidents_details = ''
                for incident in incidents
                    incidents_details += "\n#{get_incident_details(incident)}\n"
                if data_json['total'] == 0
                    msg.reply 'There are no active incidents'
                else
                    msg.reply incidents_details
        req.end()
    catch error
        scribe_log "ERROR #{error}"

#<incident>: a json object returned by the Pagerduty api for one incident
#returns a description for <incident> that includes the most relevant parameters
get_incident_details = (incident) ->
    service = incident['service']
    trigger_summary_data = incident['trigger_summary_data']
    description = trigger_summary_data['description']
    assigned_to = incident['assigned_to']

    response = "service name: #{service.name}, "
    if(description?)
        response += "description: #{description},"
    response += "triggered at #{incident['created_on']}, " +
        "status: #{incident['status']}"

    acknowledgers = incident['acknowledgers']
    if acknowledgers?
        acknowledger_details = (acknowledger) ->
            "#{acknowledger.object.name} at #{acknowledger.at}"
        response += ', acknowledged by: ' +
            acknowledgers.map(acknowledger_details).join(', ')

    response += ", incident number: #{incident['incident_number']}"
    return response

#triggers an alert to a service given its service name
alert_service_by_name = (msg, service_name, description) ->
    auth = "Token token=#{pagerduty_api_key}"
    if service_name_key[service_name]?
        pagerduty_alert_service(msg, description,
            service_name_key[service_name])
    else
        msg.reply "No service with name \"#{service_name}\" exists"


####for debuggung only, need to be removed   -->
    if (pagerduty_api_key == undefined or pagerduty_api_key.length == 0)
        scribe_log "Missing pagerduty api key"
    else
        scribe_log "The pagerduty api key is #{pagerduty_api_key}"        
####  <--- this parts

# Commands
# --------

# TODO: Command regexes should be configurable

alert_trigger_service = /alert trigger ([^ ]+) (.+)$/i
alert_list = /alert list$/i
alert_help = /alert help$/i
alert_help_from_main = /alert help_from_main/i

commands =
    alert: [
        alert_trigger_service,
        alert_list,
        alert_help,
        alert_help_from_main
    ]

# Module exports
# --------------

module.exports = (robot) ->

    register_module_commands(robot, commands)
    service_name_key_mapping()

    robot.respond alert_trigger_service, (msg) ->
        service_name = msg.match[1]
        description = msg.match[2]
        alert_service_by_name(msg, service_name, description)

    robot.respond alert_list, (msg) ->
        get_active_incidents(msg)

    robot.respond alert_help, (msg) ->
        response = "#{bot_name} alert trigger <service_name> <description>: " +
            "triggers an alert to the service with the specified name\n" +
            "#{bot_name} alert list: " +
            "lists the details of the active Pagerduty alerts"
        msg.reply response

    robot.respond alert_help_from_main, (msg) ->
        msg.send "#{bot_name} alert <subcommand>: manages pagerduty alerts, " +
            "see '#{bot_name} alert help' for details"

module.exports.commands = commands
