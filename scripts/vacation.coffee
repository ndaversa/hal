# Description:
#  Reads a vacation calendar and matches schedules with Slack users
#  In turn, providing notifications when are mentioned but on vacation
#
# Dependencies:
#   - underscore
#   - ical
#   - moment
#   - fuse.js
#   - cron
#
# Configuration:
# HUBOT_VACATION_ICAL
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require 'underscore'
obfuscator = require './obfuscator'
ical = require 'ical'
moment = require 'moment'
Fuse = require 'fuse.js'
cronJob = require("cron").CronJob

calendarUrl = process.env.HUBOT_VACATION_ICAL
onVacationUsers = []
onVacationRegex = null

module.exports = (robot) ->

  lookupUser = (name) ->
    users = robot.brain.users()
    users = _(users).keys().map (id) -> users[id]
    f = new Fuse users,
      keys: ['name', 'real_name', 'email_address']
      shouldSort: yes
    results = f.search name
    result = if results? and results.length >=1 then results[0] else null
    return result

  determineWhosOnVacation = (callback) ->
    now = moment()
    ical.fromURL calendarUrl, {}, (err, data) ->
      onVacation = _(data).keys().map (id) ->
        event = data[id]
        start: moment event.start
        end: moment event.end
        summary: event.summary
        id: id
      .filter((event) -> now.isBetween event.start, event.end)
      .map((event) -> event.summary.split('-')[0].trim())
      .map(lookupUser)
      callback _(onVacation).compact()

  updateVacationList = () ->
    determineWhosOnVacation (users) ->
      if users and users.length > 0
        onVacationUsers = users
        onVacationRegex = eval "/\\b(#{(users.map (user) -> user.name).join '|'})\\b/gi"
      else
        onVacationUsers = []
        onVacationRegex = null

  userOnVacationMentioned = (message) ->
    return false if not onVacationRegex
    return false if not message.match?
    return message.match onVacationRegex

  robot.listen userOnVacationMentioned, (msg) ->
    for username in msg.match
      user = _(onVacationUsers).find (user) -> user.name is username
      msg.send "<@#{msg.message.user.id}>: #{obfuscator.obfuscate user.name} is on vacation :sunglasses:"

  robot.brain.once 'loaded', ->
    updateVacationList()
    new cronJob( "0 */15 * * * *", updateVacationList, null, true)
