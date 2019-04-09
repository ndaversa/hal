# Description:
#  Track Device Sessions
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   None
#
# Author:
#   ndaversa

crypto = require "crypto"

class Sessions

  @key: "trackerbot-sessions"

  constructor: (@robot) ->
    return new Sessions @robot unless @ instanceof Sessions
    @robot.brain.once 'loaded', =>
      @sessions = @robot.brain.get(Sessions.key) or {}

  save: ->
    @robot.brain.set Sessions.key, @sessions

  all: -> return @sessions

  get: (id) ->
    return @sessions unless id
    return @sessions[id]

  end: (details) ->
    return @sessions unless details.id
    delete @sessions[details.id]
    @save()

  create: (details) ->
    details.time = Date.now()
    @sessions[details.id] = details
    @save()
    @sessions[details.id]

module.exports = Sessions
