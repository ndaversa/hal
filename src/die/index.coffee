# Description:
#  Kills hubot so it can be reborn like a phoenix from the ashes
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   die - forces hubot to restart
#
# Author:
#   ndaversa

_ = require "underscore"
Bot = require "../bot"

class DieBot extends Bot

  constructor: ->
    @commands = [
      regex: /die/i
      name: "dieCommand"
    ]
    super

  dieCommand: (context) ->
    @send context, "https://www.youtube.com/watch?v=c8N72t7aScY"
    console.log "Received `die` command, exiting..."
    console.log "I'm scared Dave...  I'm scared."
    _.delay (-> process.exit(1)), 500

module.exports = DieBot
