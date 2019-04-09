# Description:
#  Send a message to a channel anonymously
#
# Dependencies:
#   - underscore
#
# Configuration:
#   None
#
# Commands:
#   anonymous <channel> <message>
#
# Author:
#   ndaversa

_ = require "underscore"
Bot = require "../bot"
Config = require "../config"
Utils = require "../utils"

class AnonymousBot extends Bot

  constructor: ->
    @commands = [
      regex: /(?:anon|anonymous) #?([a-z0-9_-]{1,21})([^]+)/i
      name: "askCommand"
    ]
    super

  askCommand: (context) ->
    [ __, name, message ] = context.match
    channels = []

    destination = Utils.getRoom name
    for c in Config.anonymous.channels
      room = Utils.getRoom c
      channels.push " <\##{room.id}|#{room.name}>" if room
    return context.reply "You can only send anonymous messages to #{channels}" unless destination and _(Config.anonymous.channels).contains name

    @send destination, message

module.exports = AnonymousBot
