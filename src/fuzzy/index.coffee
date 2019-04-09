# Description:
#  Test the fuzzy matching function quickly
#
# Dependencies:
#   None
#
# Configuration:
#   None
#
# Commands:
#   fuzzy <name> - to test the fuzzy matching function
#
# Author:
#   ndaversa

Bot = require "../bot"
Utils = require "../utils"

class FuzzyBot extends Bot

  constructor: ->
    @commands = [
      regex: /fuzzy (.*)/i
      name: "fuzzyCommand"
    ]
    super

  fuzzyCommand: (context) ->
    [ __, name ] = context.match
    @send context, """
      Match for `#{name}`
      ```#{JSON.stringify Utils.fuzzyFindChatUser name}```
    """

module.exports = FuzzyBot
