# Integration tests for pasha_commands module
# -------------------------------------------

# Node imports
path = require('path')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
Message = require('hubot/src/message')
TextMessage = Message.TextMessage
# Pasha imports
commands_module = require('../scripts/commands')
main_module = require('../scripts/pasha_main')

# Integration tests
# -----------------

describe 'commands robot.respond listener', ->
    robot_name = "pasha"
    robot = null
    user = null
    adapter = null

    bad_command_regex = /^Command not found:/
    bad_argument_regex = /^Incorrect arguments for command:/

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join('node_modules/hubot-scripts/src/scripts')
                ),
                'auth.coffee'
            )
            commands_module robot
            main_module robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()

        # Register commands manually
        robot.registered_commands =
            'good': [/^good$/, /^good girl$/, /^good year \d\d/]
            'cool': [/^cool$/, /^cool girl$/, /^cool year \d\d/]
            'healthcheck': [/healthcheck/]
        
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should show bad-command-message if input is not valid command',
    (done) ->
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            assert.match(response, bad_command_regex,
                'should show bad command message')
            assert.notMatch(response, bad_argument_regex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} someBadCommand"))

    it 'should show bad-argument-message if input is not valid command',
    (done) ->
        adapter.on "reply", (envelope, response_lines) ->
            response = response_lines[0]
            assert.notMatch(response, bad_command_regex,
                'should not show bad command message')
            assert.match(response, bad_argument_regex,
                'should show bad argument message')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} good someBadArgument"))

    it 'should not return any error message in the help response ' +
    'if no command is passed to the bot', (done) ->
        adapter.on "send", (envelope, response_lines) ->
            response = response_lines[0]
            assert.notMatch(response, bad_command_regex,
                'should not show bad command message')
            assert.notMatch(response, bad_argument_regex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name}"))

    it 'should not return any error message in the help response ' +
    'if only whitespaces are addressed to the bot', (done) ->
        adapter.on 'send', (envelope, response_lines) ->
            response = response_lines[0]
            assert.notMatch(response, bad_command_regex,
                'should not show bad command message')
            assert.notMatch(response, bad_argument_regex,
                'should not show bad argument message')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name}    "))

    it 'should not return any error message if the input is a valid command',
    (done) ->
        error = 0
        adapter.on "reply", (envelope, response_lines) ->
            response = response_lines[0]
            if response.match(bad_command_regex)
                error = 1
            if response.match(bad_argument_regex)
                error = 1
        adapter.receive(new TextMessage(user, "#{robot_name} healthcheck"))
        setTimeout () ->
            assert.equal(error, 0, 'should not return error message')
            done()
        , 500
