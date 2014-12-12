# Integration tests for pasha_changelog module
# ---------------------------------------

# Node imports
path = require('path')
nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pasha_changelog = require('../scripts/pasha_changelog')
splitMessages = pasha_changelog.splitMessages
pasha_changelog_commands = pasha_changelog.commands

bot_name = constant.bot_name
MSG_MAX = constant.hipchat_message_limit
changelog_hostname = constant.changelog_hostname
changelog_port = constant.changelog_port

describe 'command registration', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pasha_changelog robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach () ->
        robot.shutdown()

    it 'should register changelog commands in robot.registered_commands', () ->
        for command, regexes of pasha_changelog_commands
            assert.property(robot.registered_commands, command)
            regexes = regexes.toString()
            registered_regexes = robot.registered_commands[command].toString()
            assert.equal(regexes, registered_regexes)

describe 'changelog command', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            pasha_changelog robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach () ->
        robot.shutdown()

    it 'should post event to changelog', () ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}").post('/api/events',
            {criticality: 1, unix_timestamp: timestamp,
            category: "pasha", description: "mocha: foo"}).reply(200, 'OK')
        adapter.receive(new TextMessage(user,
            "#{robot_name} changelog add foo"))
        # TODO: test that post is sent to changelog
        #       (`post_to_changelog` is called)
        # TODO: test that msg.reply happens

    it 'should silently post event to changelog', () ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}").post('/api/events',
            {criticality: 1, unix_timestamp: timestamp,
            category: "pasha", description: "foo"}).reply(200, 'OK')
        adapter.receive(new TextMessage(user,
            "#{robot_name} changelog addsilent foo"))
        # TODO: test that reply happens

    it 'should display changelog events', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,
                [{category: "foo", unix_timestamp: (timestamp - 12),
                description: "hello", criticality: 2},
                {category: "bar", unix_timestamp: (timestamp - 7),
                description: "world", criticality: 2}])
        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0].split("\n")
            assert.equal(lines[0],
                "#{(new Date((timestamp - 12) * 1000)).toISOString()} " +
                "- foo - hello",
                'should display changelog events')
            assert.equal(lines[1],
                "#{(new Date((timestamp - 7) * 1000)).toISOString()} " +
                "- bar - world",
                'should display changelog events')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} changelog 5m"))

    it 'should display "No entries to show" ' +
    'if there are no entries in the given period', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}").
            get('/api/events?hours_ago=1&until=-1').reply(200, [])

        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0].split('\n')
            assert.equal(lines.length, 1, 'should send only one message')
            assert.equal(lines[0], 'No entries to show')
            done()

        adapter.receive(new TextMessage(user, "#{robot_name} changelog 5m"))

     it 'should display "The total lenghts of the entries is exceeds the limit"
        message if there are too many entries and no force-flag', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,[{category: "foo", unix_timestamp: (timestamp - 12)
                , description: Array(MSG_MAX).join("a"), criticality: 2}])
        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0].split("\n")
            assert.equal(lines.length, 2, 'should send 2 messages')
            assert.equal(lines[0], 'Too many entries to show')
            assert.equal(lines[1],
                'Add -f to get the entries in seperate messages')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} changelog 5m"))

     it 'should display the split entries if the force-flag is added', (done) ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock("https://#{changelog_hostname}")
            .get('/api/events?hours_ago=1&until=-1')
            .reply(200,[{category: "foo", unix_timestamp: (timestamp - 12)
                , description: Array(MSG_MAX).join("a"), criticality: 2}])
        resp = "#{(new Date((timestamp - 12) * 1000)).toISOString()} " +
            "- foo - #{Array(MSG_MAX).join("a")}\n"
        expected_msg = splitMessages(resp)
        no_msg_received = 0
        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0]
            assert.equal(lines, expected_msg[no_msg_received],
                'should display the relevant chunk of the full message')
            no_msg_received++
            if(no_msg_received == expected_msg.length)
                done()
        adapter.receive(new TextMessage(user, "#{robot_name} changelog 5m -f"))
