# Integration tests for pasha_provision module
# --------------------------------------------

# Node imports
path = require('path')
nock = nock = require('nock')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
constant = require('../pasha_modules/constant').constant
pasha_provision = require('../scripts/pasha_provision')
pasha_provision_commands = pasha_provision.commands

bot_name = constant.bot_name
PROVISION_HOST_NAME = process.env.PROVISION_HOST_NAME

describe 'command registration', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null

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
            pasha_provision robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register provision commands in robot.registered_commands', () ->
        for command, regexes of pasha_provision_commands
            assert.property(robot.registered_commands, command)
            regexes = regexes.toString()
            registered_regexes = robot.registered_commands[command].toString()
            assert.equal(regexes, registered_regexes)

describe 'provision commands', () ->
    robot_name = bot_name
    robot = null
    user = null
    adapter = null

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
            pasha_provision robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it "should post runchef command to #{PROVISION_HOST_NAME}", () ->
        provision_api = nock("https://#{PROVISION_HOST_NAME}")
            .post('/runchef/', 'data={"criteria": "role:foo"}')
            .reply(200, 'OK')
        adapter.receive(new TextMessage(user, "#{robot_name} runchef role:foo"))

    it "should post runchef command to #{PROVISION_HOST_NAME}", () ->
        provision_api = nock("https://#{PROVISION_HOST_NAME}")
            .post('/reboot/', 'data={"criteria": "role:foo"}')
            .reply(200, 'OK')
        adapter.receive(new TextMessage(user, "#{robot_name} reboot role:foo"))
