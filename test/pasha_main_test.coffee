# Integration tests for pasha_main module
# ---------------------------------------

# Node imports
path = require('path')
_ = require('underscore')
chai = require('chai')
assert = chai.assert
expect = chai.expect
nock = require('nock')
# Hubot imports
Robot = require('hubot/src/robot')
TextMessage = require('hubot/src/message').TextMessage
# Pasha imports
Prio1 = require('../pasha_modules/model').Prio1
State = require('../pasha_modules/model').State
constant = require('../pasha_modules/constant').constant
pasha_main = require('../scripts/pasha_main')
pasha_main_commands = pasha_main.commands

bot_name = constant.bot_name
playbook_url = process.env.PRIO1_PLAYBOOK_URL
prio1_monitored_website = process.env.PRIO1_MONITORED_WEBSITE
changelog_hostname = constant.changelog_hostname


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
            pasha_main robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register prio1 commands in robot.registered_commands', () ->
        for command, regexes of pasha_main_commands
            assert(command of robot.registered_commands)
            regexes = regexes.toString()
            registered_regexes = robot.registered_commands[command].toString()
            assert.equal(regexes, registered_regexes)

describe 'prio1 command', () ->
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
            pasha_main robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should accept start if there is no prio1 and show Playbook url', (done) ->
        robot.brain.set(constant.pasha_state_key, JSON.stringify(new State()))
        hipchat_api_message1 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=undefined',
                "room_id=room1&from=Pasha&message=mocha started a prio1: " +
                "big trouble. you can confirm it by joining the 'Ops' room " +
                "and saying '#{bot_name} prio1 confirm'&notify=1"
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                "room_id=room2&from=Pasha&message=mocha started a prio1: " +
                "big trouble. you can confirm it by joining the 'Ops' room " +
                "and saying '#{bot_name} prio1 confirm'&notify=1"
            ).reply(200, '{"status":"sent"}')
        adapter.on "send", (envelope, response_lines) ->
            first_line = response_lines[0].split("\n")[0]
            assert.equal(first_line, 'mocha started the prio1: big trouble',
                'should accept start if there is no prio1')
            expected = "Prio1 Playbook URL = #{playbook_url}"
            expect(response_lines.toString()).to.contain(expected);
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} prio1 start big trouble"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        assert(pasha_state?)
        assert(pasha_state.prio1?)
        assert(pasha_state.prio1.time?)
        assert(pasha_state.prio1.time.start?)
        timestamp = pasha_state.prio1.time.start
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', timestamp,
            'big trouble')))
        assert(_.isEqual(prio1, pasha_state.prio1))

    it 'should not accept start if there is a prio1', (done) ->
        pasha_state = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line, 'you cannot start a prio1: ' +
                'there is one currently going on',
                'should not accept start if there is a prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} prio1 start big trouble"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        assert(_.isEqual(prio1, pasha_state.prio1))

    it 'should show url-specific infos in the prio1 help message', (done) ->
        pasha_state = new State()
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'send', (envelope, response_lines) ->
            expected = "Prio1 Playbook URL = #{playbook_url}"
            expect(response_lines.toString()).to.contain(expected);
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 help"))

    it 'should show url-specific infos in the prio1 start message', (done) ->
        pasha_state = new State()
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'send', (envelope, response_lines) ->
            if(playbook_url? and  playbook_url.length > 0)
                expected = "Prio1 Playbook URL = #{playbook_url}"
                expect(response_lines.toString()).to.contain(expected)
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 start"))

    it 'should accept confirm if there is an unconfirmed prio1', (done) ->
        pasha_state = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        hipchat_api_roomlist = nock('https://api.hipchat.com')
            .get('/v1/rooms/list?format=json&auth_token=undefined')
            .reply(200, '{"rooms": [{"room_id": 0, "name": "mocha", ' +
                '"topic": "foo"}]}')
        hipchat_api_message1 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room1&from=Pasha&message=mocha confirmed the prio1' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock('https://api.hipchat.com')
        .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room2&from=Pasha&message=mocha confirmed the prio1' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        pagerduty_api = nock('https://events.pagerduty.com')
        .post('/generic/2010-04-15/create_event.json',
            {
                service_key: "pdkey"
                event_type: "trigger"
                description: "outage: big trouble"
            }).reply(200, '{"status":"success","message":"Event processed",' +
                '"incident_key":"pdkey"}')
        adapter.on "send", (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line, 'mocha confirmed the prio1',
                'should accept confirm is there is an unconfirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 confirm"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        assert(pasha_state?)
        assert(pasha_state.prio1?)
        assert(pasha_state.prio1.time?)
        assert(pasha_state.prio1.time.start?)
        timestamp = pasha_state.prio1.time.confirm
        prio1.time.confirm = timestamp
        prio1.role.confirmer = 'mocha'
        assert(_.isEqual(prio1, pasha_state.prio1))

    it 'should not accept confirm if there is no prio1', (done) ->
        robot.brain.set(constant.pasha_state_key, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line, 'you cannot confirm the prio1: ' +
                'there is no prio1 going on',
                'should not accept confirm if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 confirm"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        empty_state = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(empty_state, pasha_state))

    it 'should not accept confirm if the prio1 already is confirmed', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        prio1.time.confirm = '1234'
        prio1.role.confirmer = 'mocha'
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'the prio1 already is confirmed',
                'should not accept confirm if the prio1 already is confirmed')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 confirm"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should accept stop if there is an unconfirmed prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        hipchat_api_message1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room1&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock("https://api.hipchat.com")
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room2&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        adapter.on "send", (envelope, response_lines) ->
            first_line = response_lines[0].split("\n")[0]
            assert.equal(first_line, 'mocha stopped the prio1: big trouble',
                'should accept stop if there is an unconfirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 stop"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should accept stop if there is a confirmed prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        prio1.time.confirm = 1234
        prio1.role.confirmer = 'mocha'
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        hipchat_api_message1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room1&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room2&from=Pasha&message=mocha stopped the prio1: ' +
                'big trouble&notify=1'
            ).reply(200, '{"status":"sent"}')
        adapter.on 'send', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line, 'mocha stopped the prio1: big trouble',
                'should accept stop if there is a confirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 stop"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should not accept stop if there is no prio1', (done) ->
        pasha_state = new State()
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert (first_line == 'you cannot stop the prio1: ' +
                'there is no prio1 going on'),
                'should not accept confirm if there is no prio1'
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} prio1 stop"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(new State()))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should set comm role if there is a prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state = new State()
        pasha_state.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'send', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'comm role is now assigned to ' +
                "Clint Eastwood, you can change it with " +
                "'#{bot_name} role comm <name>'",
                'should set comm role if there is a prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} role comm clint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        pasha_state.prio1.role.comm = 'Clint Eastwood'
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should not set comm role if there is no prio1', (done) ->
        pasha_state = new State()
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'you cannot set the comm role: ' +
                'there is no prio1 going on',
                'should not set comm role if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} role comm clint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should not set comm role if there is no matching user', (done) ->
        pasha_state = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'no such user: klint',
                'should not set comm role if there is no matching user')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} role comm klint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should set leader role if there is a prio1', (done) ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state = new State()
        pasha_state.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on "send", (envelope, response_lines) ->
            assert.equal(response_lines[0], "leader role is now assigned to " +
                "Clint Eastwood, you can change it with " +
                "'#{bot_name} role leader <name>'",
                'should set comm role if there is a prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} role leader clint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        pasha_state.prio1.role.leader = "Clint Eastwood"
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should not set leader role if there is no prio1', (done) ->
        pasha_state = new State()
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'you cannot set the leader role: ' +
                'there is no prio1 going on',
                'should not set leader role if there is no prio1')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} role leader clint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should not set leader role if there is no matching user', (done) ->
        pasha_state = new State()
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0, 'big trouble')))
        pasha_state.prio1 = prio1
        users = [{name: "Clint Eastwood", mention_name: "clint"}]
        pasha_state.users = users
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.equal(response_lines[0], 'no such user: klint',
                'should not set leader role if there is no matching user')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} role comm klint"))
        new_pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        pasha_state = JSON.parse(JSON.stringify(pasha_state))
        assert(_.isEqual(new_pasha_state, pasha_state))

    it 'should find the user by full name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        get_user = require('../pasha_modules/util').get_user
        assert(_.isEqual(user, get_user('Clint Eastwood', 'foo', users)))

    it 'should find the user by mention name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        get_user = require('../pasha_modules/util').get_user
        assert(_.isEqual(user, get_user('clint', 'foo', users)))

    it 'should find the user by partial name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        get_user = require('../pasha_modules/util').get_user
        assert(_.isEqual(user, get_user('East', 'foo', users)))

    it 'should not find the user if there is no matching name', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user]
        get_user = require('../pasha_modules/util').get_user
        assert(_.isEqual(null, get_user('John', 'foo', users)))

    it 'should not find the user if there are multiple matching names', ->
        user = {name: "Clint Eastwood", mention_name: "clint"}
        users = [user, user]
        get_user = require('../pasha_modules/util').get_user
        assert(_.isEqual(null, get_user('East', 'foo', users)))

    it 'should download the users from hipchat', ->
        set_users = (users) ->
            assert(_.isEqual([{"name": "Clint Eastwood"}], users))
        hipchat_api_users = nock('https://api.hipchat.com')
            .get('/v1/users/list?format=json&auth_token=')
            .reply(200, '{"users": [{"name": "Clint Eastwood"}]}')
        download_users = require('../pasha_modules/util').download_users
        download_users('', set_users)

    it 'should display status if there is an unconfirmed prio1', ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0].split("\n")
            assert.equal(lines[0], 'Prio1 status: big trouble',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[1], 'Started: mocha at 1970-01-01T03:25:45.000Z',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[2], 'Confirmed: null at null',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[3], 'Leader: mocha',
                'should display status if there is an unconfirmed prio1')
            assert.equal(lines[4], 'Communication: null',
                'should display status if there is an unconfirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} status"))

    it 'should display status if there is a confirmed prio1', ->
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        prio1.time.confirm = '12346'
        prio1.role.confirmer = 'yeti'
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.on 'send', (envelope, response_lines) ->
            lines = response_lines[0].split('\n')
            assert.equal(lines[0], 'Prio1 status: big trouble',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[1], 'Started: mocha at 1970-01-01T03:25:45.000Z',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[2],
                'Confirmed: yeti at 1970-01-01T03:25:46.000Z',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[3], 'Leader: mocha',
                'should display status if there is a confirmed prio1')
            assert.equal(lines[4], 'Communication: null',
                'should display status if there is a confirmed prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} status"))
        
    it 'should not display status if there is no prio1', (done) ->
        robot.brain.set(constant.pasha_state_key, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line, 'cannot display prio1 status: ' +
                'there is no prio1 going on',
                'should not display status if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} status"))

    it 'should set status if there is an unconfirmed prio1', ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock(changelog_hostname).post('/api/events',
            {"criticality": 1, "unix_timestamp": timestamp,
            "category": "pasha", "description": "mocha set status to foo"})
            .reply(200, 'OK')
        hipchat_api_message1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room1&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room2&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345,
            'big trouble')))
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.receive(new TextMessage(user, "#{robot_name} status foo"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        assert(pasha_state?)
        assert(pasha_state.prio1?)
        assert(pasha_state.prio1.status?)
        assert.equal(pasha_state.prio1.status, 'foo')

    it 'should set status if there is a confirmed prio1', ->
        timestamp = Math.floor((new Date()).getTime() / 1000)
        changelog_api = nock(changelog_hostname).post('/api/events',
            {"criticality": 1, "unix_timestamp": timestamp,
            "category": "pasha", "description": "mocha set status to foo"})
            .reply(200, 'OK')
        hipchat_api_message1 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                "room_id=room1&from=Pasha&message=mocha set status to foo" +
                "&notify=1"
            ).reply(200, '{"status":"sent"}')
        hipchat_api_message2 = nock('https://api.hipchat.com')
            .post('/v1/rooms/message?format=json&auth_token=undefined',
                'room_id=room2&from=Pasha&message=mocha set status to foo' +
                '&notify=1'
            ).reply(200, '{"status":"sent"}')
        prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 12345, +
            'big trouble')))
        prio1.time.confirm = '12346'
        prio1.role.confirmer = 'yeti'
        pasha_state = new State()
        pasha_state.prio1 = prio1
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))
        adapter.receive(new TextMessage(user, "#{robot_name} status foo"))
        pasha_state = JSON.parse(robot.brain.get(constant.pasha_state_key))
        assert(pasha_state?)
        assert(pasha_state.prio1?)
        assert(pasha_state.prio1.status?)
        assert.equal(pasha_state.prio1.status, 'foo')

    it 'should not set status if there is no prio1', (done) ->
        robot.brain.set(constant.pasha_state_key, JSON.stringify(new State()))
        adapter.on 'reply', (envelope, response_lines) ->
            first_line = response_lines[0].split('\n')[0]
            assert.equal(first_line,
                'cannot set prio1 status: there is no prio1 going on',
                'should not display status if there is no prio1')
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} status foo"))

describe 'prio1 reminder', ->
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
                    path.join("node_modules/hubot-scripts/src/scripts")
                ),
                'auth.coffee'
            )
            pasha_main robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    prio1_synonyms = ['prio1', 'prio 1', 'outage']
    if(prio1_monitored_website? and prio1_monitored_website.length > 0)
        prio1_synonyms.push("#{prio1_monitored_website} is down")
    for synonym in prio1_synonyms
        it "should be sent when there is no prio1 running " +
        "and #{synonym} is mentioned", (done) ->
            pasha_state = new State()
            pasha_state.prio1 = undefined
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))

            adapter.on 'send', (envelope, response_lines) ->
                first_line = response_lines[0].split("\n")[0]
                expected = 'Is there a prio1? If yes, please register it ' +
                           'with "pasha prio1 start <description of the issue>"'
                assert.equal(first_line, expected)
                done()
            adapter.receive(new TextMessage(user, "#{synonym} happening"))

    # TODO: change implementation
    for synonym in prio1_synonyms
        it "should not be sent if a prio1 has already been started," +
           " even if #{synonym} is mentioned", (done) ->
            pasha_state = new State()
            prio1 = JSON.parse(JSON.stringify(new Prio1('mocha', 0,
                'big trouble')))
            pasha_state.prio1 = prio1
            robot.brain.set(constant.pasha_state_key,
                JSON.stringify(pasha_state))

            error = 0
            adapter.on 'send', (envelope, response_lines) ->
                first_line = response_lines[0].split("\n")[0]
                unexpected = 'Is there a prio1? If yes, please register it ' +
                           'with "pasha prio1 start <description of the issue>"'
                if first_line == unexpected
                    error = 1
            adapter.receive(new TextMessage(user, "#{synonym} still running?"))
            setTimeout () ->
                if error == 1
                    throw new Error()
                done()
            , 500

    # TODO: change implementation
    it 'should not be sent if the message is addressed to the robot', (done) ->
        pasha_state = new State()
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))

        error = 0
        adapter.on 'send', (envelope, response_lines) ->
            first_line = response_lines[0].split("\n")[0]
            unexpected = 'Is there a prio1? If yes, please register it ' +
                       'with "pasha prio1 start <description of the issue>"'
            if first_line == unexpected
                error = 1
        adapter.receive(new TextMessage(user, "#{bot_name} prio1 start"))
        setTimeout () ->
            if error == 1
                throw new Error()
            done()
        , 500

    # TODO: change implementation
    it 'should not be sent if a message contains no prio1 synonyms', (done) ->
        pasha_state = new State()
        robot.brain.set(constant.pasha_state_key, JSON.stringify(pasha_state))

        error = 0
        adapter.on 'send', (envelope, response_lines) ->
            first_line = response_lines[0].split("\n")[0]
            unexpected = 'Is there a prio1? If yes, please register it ' +
                       'with "pasha prio1 start <description of the issue>"'
            if first_line == expected
                error = 1
        adapter.receive(new TextMessage(user, 'hello world'))
        setTimeout () ->
            if error == 1
                throw new Error()
            done()
        , 500
