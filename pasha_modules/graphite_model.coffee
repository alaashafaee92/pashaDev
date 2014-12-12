url_module = require('url')

class Graphite

    constructor: () ->
        # The keys of @charts denote the names of graphs and the corresponding
        # values are their urls
        @charts = {}

    set_charts: (charts) ->
        @charts = charts

    get_charts: () ->
        @charts

    get_chart: (chart_name) ->
        @charts[chart_name]

    add_chart: (chart_name, chart) ->
        @charts[chart_name] = chart

    remove_chart: (chart_name) ->
        if @charts[chart_name] == undefined
            return false
        else
            delete @charts[chart_name]
            return true

    # Adds a new metric (target) to the graph called chart_name
    add_target: (chart_name, target) ->
        chart_url = @get_chart chart_name
        url = null
        if chart_url?
            url = append_target_to_url chart_url, target
            @add_chart chart_name, url
        return url

    # Removes an existing metric (target) fom the graph called chart_name
    remove_target: (chart_name, target) ->
        chart_url = @get_chart chart_name
        if chart_url == undefined
            return {
                success: false
                error_msg: "No chart with name #{chart_name} is found"
            }
        response = remove_target_from_url chart_url, target
        if response.success
            @add_chart chart_name, response.url
        return response

    has_chart: (chart_name) ->
        @charts[chart_name]?

    # Adds one more value to the target parameter in a graph url
    # This is equivalent to adding a metric in a graph
    append_target_to_url = (url, target) ->
        url_parts = url_module.parse(url, true)
        url_params = url_parts.query
        if not url_params.target?
            url_params['target'] = target
        else
            url_params['target'].push(target)
        # http://stackoverflow.com/questions/7517332/node-js-url-parse-result-back-to-string
        # When you modify urlparts.query, url_parts.search remains unchanged and
        # it is used in formatting the url. So to force it to use query, simply
        # remove search from the object:
        delete url_parts.search
        url_module.format(url_parts)

    # Removes one metric (target) from a graph url if it already exists
    remove_target_from_url = (url, target) ->
        url_parts = url_module.parse(url, true)
        url_params = url_parts.query
        if not url_params.target?
            return {
                success: false
                error_msg: "The url of this graph does not contain any targets."
            }
        
        target_index = url_params.target.indexOf target
        if target_index == -1
            return {
                success: false
                error_msg: "No target with this name exists in this graph."
            }
                
        # The value of the target parameter is a String only if there is one
        # target in the graph. Otherwise, it is an array.
        if typeof url_params.target == "string"
            return {
                success: false
                error_msg: "You cannot remove the only target of this graph." +
                    " Please consider removing the whole graph instead."}
        
        url_params.target.splice target_index, 1
        # http://stackoverflow.com/questions/7517332/node-js-url-parse-result-back-to-string
        # When you modify urlparts.query, url_parts.search remains unchanged and
        # it is used in formatting the url. So to force it to use query, simply
        # remove search from the object:
        delete url_parts.search
        {success: true, url: url_module.format(url_parts)}


module.exports = {
    Graphite: Graphite
    graphite_key: "GRAPHITE"
}
