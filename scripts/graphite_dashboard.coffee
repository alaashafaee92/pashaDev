# Description
#   A server that responds to GET requests with path '/graphs'.
#   It responds with the existing graphs on the server.
#
# Configuration:
#   Change port and host params to match your deployment settings.
#   Specify the appropriate 'Access-Control-Allow-Origin' in response headers.

graphite_util = require('../pasha_modules/graphite_util')
scribe_log = require('../pasha_modules/scribe_log').scribe_log
http = require('http')
fs = require('fs')
url = require('url')

module.exports = (robot) ->
  
    server = http.createServer((req, res) ->
        path = url.parse(req.url).pathname
        if req.method is 'GET'
            switch path
                when '/graphs'
                    res.writeHead 200,
                        "Content-Type": "text/plain",
                        "Access-Control-Allow-Origin": "*"
                    charts = graphite_util.get_graphite_charts(robot)
                    res.write JSON.stringify(charts)
                    res.end()
    )

    port = 8001
    host = '127.0.0.1'
    server.listen(port, host)
    scribe_log 'Prio1-dashboard server listening at http://' + host + ':' + port
