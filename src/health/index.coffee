# Description:
#  A bot that checks the health of the hubot
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

Bot = require "../bot"
Server = require "../bot/server"
Config = require "../config"

class HealthBot extends Bot
  @include Server

  constructor: (@robot) ->
    return new HealthBot @robot unless @ instanceof HealthBot
    @endpoints = [
      path: "/healthz"
      type: "get"
      func: @getHealthz
    ]
    super

  isAuthorized: -> yes #TODO: don't need auth on this endpoint

  credentials:
    token: Config.slack.token

  getHealthz: (req, res) ->
    return res.json {}
    @fetch "https://slack.com/api/users.getPresence",
      querystring: yes
      user: @robot.adapter.self.id
    .then (json) =>
      if json.presence is "active"
        res.json json
      else
        res.status(500).send "#{@robot.name} is offline"
    .catch (error) =>
      res.status(500).send "#{@robot.name} is offline"
      @robot.logger.error "#{@robot.name} is offline"
      @robot.logger.error error

module.exports = HealthBot
