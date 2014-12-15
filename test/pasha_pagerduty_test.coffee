# Integration tests for pasha_pagerduty module
# --------------------------------------------

# Node imports
path = require('path')
nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pasha_pagerduty = require('../scripts/pasha_pagerduty')
pasha_pagerduty_commands = pasha_pagerduty.commands

bot_name = constant.bot_name
PAGERDUTY_HOST_NAME = process.env.PAGERDUTY_HOST_NAME

describe 'command registration', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null
    pagerduty_get_services = null
    get_services_response  = require('../test_files/services.json')

    beforeEach (done) ->
        pagerduty_get_services = nock("https://#{PAGERDUTY_HOST_NAME}")
            .get('/api/v1/services')
            .reply(200, get_services_response)

        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pasha_pagerduty robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register pagerduty commands in robot.registered_commands', () ->
        for command, regexes of pasha_pagerduty_commands
            assert.property(robot.registered_commands, command)
            regexes = regexes.toString()
            registered_regexes = robot.registered_commands[command].toString()
            assert.equal(regexes, registered_regexes)

describe 'alert command', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null
    pagerduty_get_services = null
    get_services_response  = require('../test_files/services.json')

    beforeEach (done) ->
        pagerduty_get_services = nock("https://#{PAGERDUTY_HOST_NAME}")
            .get('/api/v1/services')
            .reply(200, get_services_response)

        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pasha_pagerduty robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should trigger an alert to a service using the service name', (done) ->

        pagerduty_alert_service = nock('https://events.pagerduty.com')
            .post('/generic/2010-04-15/create_event.json', {
                service_key: "92b0d9bc4729439dbb0ce0ac0d505a5c"
                event_type: "trigger"
                description: "Keep calm. There is no serious outage."
            }).reply(200, '{"status":"success","message":"Event processed",' +
            '"incident_key":"pdkey"}')
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], 'pagerduty alert triggered: ' +
                'Keep calm. There is no serious outage.',
                'success message of triggering the service should be received')
            done()
        setTimeout () ->
            adapter.receive(new TextMessage(user,
                "#{robot_name} alert trigger Alaa_Shafaee_test Keep calm. " +
                "There is no serious outage.")
            )
        , 1000

    it 'should inform users on trying to alert a service that does not exist',
    (done) ->
        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0],
                'No service with name "invalid_name" exists')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} alert trigger invalid_name Keep calm. " +
            "There is no serious outage."))

    it 'should list all active alerts', (done) ->
        get_incidents_response  = require('../test_files/incidents.json')
        pagerduty_get_active_incidents = nock("https://#{PAGERDUTY_HOST_NAME}")
            .get('/api/v1/incidents/?status=triggered,acknowledged')
            .reply(200, get_incidents_response)

        adapter.on 'reply', (envelope, response) ->
            incidents = response[0].split('\n\n')
            triggered_incident = incidents[0]
            acknowledged_incident = incidents[1]

            assert.match(triggered_incident, /service name: Alaa_Shafaee_test/,
                'service name should show in active incident details')
            expected_description = /description: No outage, be positive. :\)/
            assert.match(triggered_incident, expected_description,
                'outage description should show in active incident details')
            assert.match(triggered_incident, /triggered at 2014-11-19T14:23:58/,
                'incident trigger time should show in active incident details')
            assert.match(triggered_incident, /status: triggered/,
                'incident status should show in active incident details')
            assert.match(triggered_incident, /incident number: 53779/,
                'incident number should show in active incident details')
            assert.match(acknowledged_incident, /status: acknowledged/,
                'correct status should show for each active incident')
            assert.match(acknowledged_incident,
                /acknowledged by: Alaa Shafaee at 2014-11-19T17:57:12Z/,
                'names of acknowledgers and acknowledgment time' + '
                should show in the details of acknowledged incidents')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} alert list"))

    it 'should inform users when there are no active incidents', (done) ->
        get_incidents_response = '{"incidents":[],"limit":100,' +
            '"offset":0,"total":0}'
        pagerduty_get_active_incidents = nock("https://#{PAGERDUTY_HOST_NAME}")
            .get("/api/v1/incidents/?status=triggered,acknowledged")
            .reply(200, get_incidents_response)

        adapter.on 'reply', (envelope, response) ->
            assert.equal(response[0], 'There are no active incidents',
                'should return "There are no active incidents" message when ' +
                'there are no active incidents')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} alert list"))

    it 'should fail to test travis :)', (done) ->
        throw new Error()