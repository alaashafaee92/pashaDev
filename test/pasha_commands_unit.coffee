# Unit tests for pasha_commands module
# ------------------------------------

# Node imports
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
# Pasha imports
checker = require('../scripts/commands').checker
register_command = require('../scripts/commands').register_command
register_module_commands =
    require('../scripts/commands').register_module_commands
constant = require('../pasha_modules/constant').constant

bot_name = constant.bot_name

describe 'register_command', () ->
    robot_name = bot_name
    robot = null

    beforeEach () ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)

    it 'should create robot.registered_commands if it does not exist yet', () ->
        register_command robot, 'role', [/^role$/, /^role (.+)$/]
        assert.isDefined(robot.registered_commands,
            'robot.registered_commands should be created')

    it 'should insert commands with regexes into robot.commands', () ->
        register_command robot, 'role', [/^role$/, /^role (.+)$/]
        assert.isDefined(robot.registered_commands['role'],
            'robot.registered_commands should have key "role"')

        assert.equal(robot.registered_commands['role'][0].toString(),
            /^role$/.toString(),
            'robot.registered_commands should contain ' +
            'the registered "role" regexes')

        assert.equal(robot.registered_commands['role'][1].toString(),
            /^role (.+)$/.toString(),
            'robot.registered_commands should contain ' +
            'the registered "role" regexes')

describe 'register_module_commands', () ->
    robot_name = bot_name
    robot = null
    commands =
        'good': [/good boy/, /good girl/]
        'bad': [/bad boy/, /bad girl/]

    beforeEach () ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)
        register_module_commands robot, commands

    it 'should add all keys and values from commands object to ' +
    'robot.registered_commands', () ->
        assert.property(robot.registered_commands, 'good')
        assert.property(robot.registered_commands, 'bad')
        assert.equal(robot.registered_commands['good'], commands['good'])
        assert.equal(robot.registered_commands['bad'], commands['bad'])

describe 'checker', () ->

    it 'should return a function', () ->
        assert.instanceOf(checker('good'), Function)

    it 'should return a function which for a regex match returns true', () ->
        assert.isTrue(checker('good')(/good/))

    it 'should return a function which for a regex fail returns false', () ->
        assert.isFalse(checker('bad')(/good/))
