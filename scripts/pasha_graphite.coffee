# Description
#   Adds/removes graphs to/from a dashboard through Pasha commands.
#   Updates graph metrics(targets) and lists all graphs and their metrics.
#
# Dependencies
#   None
#
# Commands:
#   <bot name> graph/graphite add <graph_name> <graph_url>:
#       adds a graph to the dashboard
#   <bot name> graph/graphite remove <graph_name>:
#       removes a graph from the dashboard
#   <bot_name> graph/graphite list:
#        lists all names and urls of the graphs in the dashboard
#   <bot_name> graph/graphite target add <graph_name> <target>:
#       adds a target (metric) to certain graph
#   <bot_name> graph/graphite target remove <graph_name> <target>:
#       removes a target (metric) from certain graph
#   <bot_name> graph/graphite target <graph_name> list:
#       lists all metrics of certain graph
#   <bot_name> graph/graphite help:
#       lists the available commands to manipulate the dashboard

# Pasha imports
Graphite =  require('../pasha_modules/graphite_model').Graphite
graphite_util = require('../pasha_modules/graphite_util')
register_module_commands =
    require('../scripts/commands').register_module_commands
constant = require('../pasha_modules/constant').constant

bot_name = constant.bot_name

# Commands
# --------

# TODO: Command regexes should be configurable

graphite_add_graph = /graph(ite)? add ([^ ]+) (.+)/i
graphite_remove_graph = /graph(ite)? remove ([^ ]+)/i
graphite_list_graphs = /graph(ite)? list$/i
graphite_add_target = /graph(ite)? target add ([^ ]+) (.+)$/i
graphite_remove_target = /graph(ite)? target remove ([^ ]+) (.+)$/i
graphite_list_targets = /graph(ite)? target list ([^ ]+)$/i
graphite_help = /graph(ite)? help$/i
graph_help_main = /graph help_from_main/i

graphite_commands = [graphite_add_graph,
                    graphite_remove_graph,
                    graphite_list_graphs,
                    graphite_add_target,
                    graphite_remove_target,
                    graphite_list_targets,
                    graphite_help,
                    graph_help_main]

commands =
    "graphite" : graphite_commands
    "graph" : graphite_commands

#Register commands for the error-handling module
register_graphite_commands = (robot) ->

    register_command(robot, commands)

module.exports = (robot) ->

    graphite_util.get_or_init_graphite(robot)
    register_module_commands(robot, commands)

    robot.respond graphite_add_graph, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        chart_name = msg.match[2]
        chart_targets = msg.match[3]
        is_replacement = graphite.has_chart(chart_name)
        graphite.add_chart(chart_name, chart_targets)
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        if(is_replacement)
            msg.reply "Replaced chart #{chart_name}"
        else
            msg.reply "Successfully added #{chart_name}"

    robot.respond graphite_remove_graph, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        chart_name = msg.match[2]
        chart_targets = msg.match[3]
        chart_is_removed = graphite.remove_chart(chart_name, chart_targets)
        if(chart_is_removed)
            robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
            msg.reply "Successfully deleted #{chart_name}"
        else
            msg.reply "No chart with name '#{chart_name}' exists"

    robot.respond graphite_list_graphs, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        charts = graphite.get_charts()
        if Object.keys(charts).length == 0
            msg.reply 'There are no charts to display'
        else
            charts_str = ''
            for chart_name, chart of charts
                charts_str += "#{chart_name} -> #{chart}\n\n"
            msg.reply charts_str

    robot.respond graphite_add_target, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        chart_name = msg.match[2]
        target = msg.match[3]
        url = graphite.add_target chart_name, target
        robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
        if(url?)
            msg.reply "Added a target. The new url is: #{url}"
        else
            msg.reply "No chart with name #{chart_name} is found"

    robot.respond graphite_remove_target, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        chart_name = msg.match[2]
        target = msg.match[3]
        response = graphite.remove_target chart_name, target
        if response.success
            robot.brain.set(Graphite.graphite_key, JSON.stringify(graphite))
            msg.reply "Removed a target. The new url is: #{response.url}"
        else
            msg.reply response.error_msg

    robot.respond graphite_list_targets, (msg) ->
        graphite = graphite_util.get_or_init_graphite(robot)
        chart_name = msg.match[2]
        graphite_chart = graphite.get_chart chart_name
        if(graphite_chart?)
            targets =
                graphite_util.get_parameter_by_name "target", graphite_chart
            if targets instanceof Array
                targets = targets.join("\n\n")
            msg.reply targets
        else
            msg.reply "No chart with name '" + chart_name + "' exists"

    robot.respond graphite_help, (msg) ->
        response = "#{bot_name} graph/graphite add <graph_name> <graph_url>: " +
            "adds a graph to the Prio1-dashboard\n" +
            
            "#{bot_name} graph/graphite remove <graph_name>: " +
            "removes a graph from the Prio1-dashboard\n" +
            
            "#{bot_name} graph/graphite list: " +
            "lists all names and urls of the graphs in the Prio1-dashboard\n" +

            "#{bot_name} graph/graphite target add <graph_name> <target>: " +
            "adds a target (metric) to certain graph\n" +

            "#{bot_name} graph/graphite target remove <graph_name> <target>: " +
            "removes a target (metric) from certain graph\n" +

            "#{bot_name} graph/graphite target <graph_name> list: " +
            "lists all metrics of certain graph\n" +

            "Notes: <graph_name> cannot contain spaces\n"

        msg.reply response

    robot.respond graph_help_main, (msg) ->
        msg.send "#{bot_name} graph/graphite <subcommand>: " +
            "manages Prio1-dashboard graphs, " +
            "see '#{bot_name} graph/graphite help' for details"

module.exports.commands = commands
