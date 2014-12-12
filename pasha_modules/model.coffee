class State

    constructor: ->
        @prio1 = null
        @users = []


class Channel

    constructor: (topic) ->
        @saved_topic = topic


class Prio1

    constructor: (starter, started_timestamp, status) ->
        @title = status
        @time = {
            start: started_timestamp
            confirm: null
            last_status: started_timestamp
            recovery_eta: null
        }
        @status = status
        @role = {
            starter: starter
            confirmer: null
            leader: starter
            comm: null
        }
        @counter = {
            comm_unset_minutes: 0
            status_unset_minutes: 0
            revocery_eta_unset_minutes: 0
        }
        @url = {
            hangout: null
        }
        @channel = {}


module.exports = {
    State: State
    Channel: Channel
    Prio1: Prio1
}

