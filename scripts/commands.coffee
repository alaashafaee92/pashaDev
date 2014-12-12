# Pasha command registration and error handling

constant = require('../pasha_modules/constant').constant

bot_name = constant.bot_name

# Helpers
# -------

# Register given main command with given regexes in robot.registered_commands
# If robot.registered_commands does not exist yet,
# initializes it to an empty list.
# command: string - e.g.: 'role'
# regexes: list of regexes - e.g.: [/'role'/, /'role comm (\.+)'/, ...]
register_command = (robot, command, regexes) ->
    if robot.registered_commands == undefined
        robot.registered_commands = []
    robot.registered_commands[command] = regexes

register_module_commands = (robot, commands) ->
    for command, regexes of commands
        register_command(robot, command, regexes)

# Helper function for array.some method.
checker = (inp) ->
    (regex) ->
        (inp.match regex) != null

# Main
# ----

module.exports = (robot) ->

    robot.respond /(.*)/, (msg) ->
        inp = msg.match[1]
        if not inp
            return
        
        words = inp.split(/\s+/)

        if robot.registered_commands[words[0]] == undefined
            msg.reply "Command not found: " + words[0]
            return

        if not robot.registered_commands[words[0]].some(checker(inp))
            msg.reply "Incorrect arguments for command: #{words[0]}\n" +
                      "Type '#{bot_name} #{words[0]} help' to see command usage"
            return

module.exports.register_command = register_command
module.exports.register_module_commands = register_module_commands
module.exports.checker = checker
