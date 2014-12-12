scribe_log = require('../pasha_modules/scribe_log').scribe_log
Graphite =  require('../pasha_modules/graphite_model').Graphite

get_or_init_graphite = (adapter) ->
    pasha_graphite_key = Graphite.graphite_key
    pasha_graphite = new Graphite()
    pasha_graphite_str = adapter.brain.get(pasha_graphite_key)
    if not pasha_graphite_str?
        adapter.brain.set(pasha_graphite_key, JSON.stringify pasha_graphite)
        pasha_graphite_str = adapter.brain.get(pasha_graphite_key)
        scribe_log 'Graphite was not initialized, successfully initialized it'
    else
        pasha_graphite.set_charts JSON.parse(pasha_graphite_str).charts
    return pasha_graphite

get_graphite_charts = (adapter) ->
    graphite_str = adapter.brain.get(Graphite.graphite_key)
    graphite = JSON.parse(graphite_str)
    return graphite['charts']

get_parameter_by_name = (name, url) ->
    query = require('url').parse(url,true).query
    return query[name]


module.exports = {
    get_or_init_graphite: get_or_init_graphite
    get_graphite_charts: get_graphite_charts
    get_parameter_by_name: get_parameter_by_name
}
