# Integration tests for pasha_graphite module
# ---------------------------------------

# Node imports
path = require('path')
url_module = require('url')
assert = require('chai').assert
# Hubot imports
Robot = require('hubot/src/robot')
Message = require('hubot/src/message')
TextMessage = Message.TextMessage
# Pasha imports
pasha_graphite = require('../scripts/pasha_graphite')
pasha_graphite_commands = pasha_graphite.commands
graphite_model = require('../pasha_modules/graphite_model')
Graphite = graphite_model.Graphite
constant = require('../pasha_modules/constant').constant

bot_name = constant.bot_name

# Integration tests
# -----------------

describe 'command registration', ->
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
            pasha_graphite robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        robot.run()

    afterEach ->
        robot.shutdown()

    it 'should register graphite commands in robot.registered_commands', () ->
        for command, regexes of pasha_graphite_commands
            assert.property(robot.registered_commands, command)
            regexes = regexes.toString()
            registered_regexes = robot.registered_commands[command].toString()
            assert.equal(regexes, registered_regexes)

describe 'graphite command', () ->
    robot_name = 'pasha'
    robot = null
    user = null
    adapter = null
    graph_name = 'error'
    graph_url = 'https://graphite.organization.com/render/?width=450' +
    '&height=220&from=-4hours&template=plain' +
    '&title=Web+errors+and+warnings&' +
    'vtitle=events+per+min&drawNullAsZero=true&areaMode=stacked' +
    '&areaAlpha=0.3&target=alias(movingAverage(scale' +
    '(logster.zuisite.error.all,60),5),%27%22Org%22%20log%20errors%27)' +
    '&target=alias(secondYAxis(movingAverage(scale' +
    '(logster.zuisite.warning.all,60),5)),%27%22Org%22%20log%20warnings%27' +
    ')&colorList=%238c1e1d,%232323ff'
    existing_graph_name = 'first_chart'

    beforeEach (done) ->
        robot = new Robot(null, 'mock-adapter', false, robot_name)
        robot.adapter.on 'connected', () ->
            process.env.HUBOT_AUTH_ADMIN = '1'
            robot.loadFile(
                path.resolve(
                    path.join("node_modules/hubot-scripts/src/scripts")
                ),
                'auth.coffee'
            )
            pasha_graphite robot
            user = robot.brain.userForId('1', {
                name: "mocha"
                room: "#mocha"
                })
            adapter = robot.adapter
            done()
        graphite = new Graphite()
        graphite.charts[existing_graph_name] = 'some url'
        graphite.charts['another_graph_name'] = 'url 2'
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        robot.run()
    afterEach ->
        robot.shutdown()

    it 'should add a new graph to graphite ' +
    'if no graph with the same name already exists', (done) ->
        adapter.on "reply", (envelope, response_lines) ->
            response = response_lines[0]
            assert.equal(response, "Successfully added #{graph_name}")
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph add #{graph_name} #{graph_url}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        assert(graphite?)
        assert(graphite.charts?)
        assert(graphite.charts[graph_name]?)
        assert.equal(graphite.charts[graph_name], graph_url)
        
    it 'should replace an existing graph ' +
    'if a graph with the same name already exists', (done) ->
        new_url = 'new url'
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            assert.equal(response, 'Replaced chart first_chart')
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph add #{existing_graph_name} #{new_url}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        assert(graphite?)
        assert(graphite.charts?)
        assert(graphite.charts[existing_graph_name]?)
        assert(graphite.charts[existing_graph_name], new_url)

    it 'should be able to remove an existing graph', (done) ->
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            assert(response,
                "Successfully deleted #{existing_graph_name}")
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph remove #{existing_graph_name}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        assert(graphite?)
        assert(graphite.charts?)
        assert.isUndefined(graphite.charts[existing_graph_name])

    it 'should reply with a descriptive message ' +
    'on removing a graph that does not exist', (done) ->
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            assert.equal(response,
                "No chart with name 'non-existing_name' exists")
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph remove non-existing_name"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        assert(graphite?)
        assert(graphite.charts?)

    it 'should be able to list the existing graphs', (done) ->
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            expected_pattern = "#{existing_graph_name}(.*)some url(\n)+" +
                "another_graph_name(.*)url 2"
            assert.match(response, new RegExp(expected_pattern))
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} graph list"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
    
    it 'should reply with "There are no charts to display" ' +
    'on listing graphs if no graphs exist', (done) ->
        robot.brain.set(Graphite.graphite_key, JSON.stringify(new Graphite()))
        adapter.on 'reply', (envelope, response_lines) ->
            response = response_lines[0]
            assert.equal(response, "There are no charts to display")
            done()
        adapter.receive(new TextMessage(user, "#{robot_name} graph list"))

    it 'should be able to list the targets of an existing graph', (done) ->
        graphite = new Graphite()
        graphite.charts[graph_name] = graph_url
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on "reply", (envelope, response) ->
            response_lines = response[0].split('\n\n')
            target1 = "alias(movingAverage(scale" +
                "(logster.zuisite.error.all,60),5),'\"Org\" log errors')"
            target2 = "alias(secondYAxis(movingAverage" +
                "(scale(logster.zuisite.warning.all,60),5))," +
                "'\"Org\" log warnings')"
            assert.equal(response_lines[0], target1)
            assert.equal(response_lines[1], target2)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target list #{graph_name}"))

    it 'should be able to add a target to an existing graph', (done) ->
        graphite = new Graphite()
        graphite.charts[graph_name] = graph_url
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0], /Added a target. The new url is/)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target add #{graph_name} new_target"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        new_graph_url = graphite.charts[graph_name]
        url_params = url_module.parse(new_graph_url,true).query
        assert(url_params?)
        assert(url_params.target?)
        assert.include(url_params.target, 'new_target')

    it 'should remove an existing target of a graph ' +
    'if it is not the only target', (done) ->
        graphite = new Graphite()
        graphite.charts[graph_name] = graph_url
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        target = "alias(movingAverage(scale(logster.zuisite.error.all,60),5)" +
                ",'\"Org\" log errors')"
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0], /Removed a target. The new url is/)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target remove #{graph_name} #{target}"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        new_graph_url = graphite.charts[graph_name]
        url_params = url_module.parse(new_graph_url,true).query
        assert(url_params.target?)
        assert.notInclude(url_params.target, target)

    it 'should not remove an existing target of a graph ' +
    'if it is the only target', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0],
                /You cannot remove the only target of this graph/)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target remove sample t1"))
        graphite = JSON.parse(robot.brain.get(Graphite.graphite_key))
        new_graph_url = graphite.charts['sample']
        url_params = url_module.parse(new_graph_url,true).query
        assert(url_params.target?)
        assert.include(url_params.target, 't1')

    it 'should inform users on removing targets in a graph ' +
    'that does not have any targets', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/'
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0],
                /The url of this graph does not contain any targets/)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target remove sample t1"))

    it 'should inform users on removing targets ' +
    'that does not exist in a graph', (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0],
                /No target with this name exists in this graph./)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target remove sample t2"))

    it 'should inform users on removing targets of non-existing graphs',
    (done) ->
        graphite = new Graphite()
        graphite.charts['sample'] = 'www.graph.com/?target=t1'
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        adapter.on 'reply', (envelope, response_lines) ->
            assert.match(response_lines[0],
                /No chart with name wrong_name is found/)
            done()
        adapter.receive(new TextMessage(user,
            "#{robot_name} graph target remove wrong_name t1"))
