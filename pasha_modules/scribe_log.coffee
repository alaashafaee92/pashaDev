Scribe = require('scribe').Scribe

scribe_log = (msg) ->
    d = new Date()
    timestamp = d.toISOString()
    console.log "[#{timestamp}] #{msg}"

if (process.env.SCRIBE_SERVER_ADDRESS? and
        process.env.SCRIBE_SERVER_ADDRESS.length != 0 and
        process.env.SCRIBE_SERVER_PORT? and
        process.env.SCRIBE_SERVER_PORT.length != 0)

    scribe = new Scribe(process.env.SCRIBE_SERVER_ADDRESS,
        process.env.SCRIBE_SERVER_PORT,
        {autoReconnect:true})

    scribe.open ((err) ->
        if(err)
            return console.log(err)

    scribe_log = (msg) ->
            d = new Date()
            timestamp = d.toISOString()
            scribe.send("pasha", "[#{timestamp}] #{msg}\n"))

module.exports = {
    scribe_log
}
