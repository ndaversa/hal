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
Obfuscator = require './obfuscator'
obfuscator = new Obfuscator Obfuscator.PerfectObfuscator
ical = require 'ical'
moment = require 'moment'
Fuse = require 'fuse.js'
cronJob = require("cron").CronJob

calendarUrl = process.env.HUBOT_VACATION_ICAL
onVacationUsers = []
onVacationRegex = null

module.exports = (robot) ->

  lookupUser = (event) ->
    name = event.name.toLowerCase()
    users = robot.brain.users()
    users = _(users).keys().map (id) ->
      u = users[id]
      if not u.slack.deleted and not u.slack.is_bot and u.email_address?.includes '@wattpad'
        id: u.id
        name: u.name.toLowerCase()
        real_name: u.real_name.toLowerCase()
        email: u.email_address?.split('@')[0].toLowerCase() or ''
        event: event
      else
        null
    users = _(users).compact()

    f = new Fuse users,
      keys: ['name', 'real_name', 'email']
      shouldSort: yes
      verbose: no
    results = f.search name
    result = if results? and results.length >=1 then results[0] else null
    robot.logger.info "Matching `#{name}` with @#{result.name}"
    return result

  nextWeekday = (date) ->
    switch date.weekday()
      when 0 then return date.weekday 1 # sunday > monday
      when 6 then return date.weekday 8 # saturday > monday
      else return date

  determineWhosOnVacation = (callback) ->
    now = moment()
    ical.fromURL calendarUrl, {}, (err, data) ->
      onVacation = _(data).keys().map (id) ->
        event = data[id]
        start: moment event.start
        end: moment event.end
        summary: event.summary
        id: id
      .filter (event) ->
        now.isBetween event.start, event.end
      .map (event) ->
        event.name = event.summary.split('-')[0].trim()
        event
      .map lookupUser
      callback _(onVacation).compact()

  refreshVacationList = (callback) ->
    robot.logger.info 'Refreshing vacation list'
    determineWhosOnVacation (users) ->
      if users and users.length > 0
        onVacationUsers = users
        onVacationRegex = eval "/\\b(#{(users.map (user) -> user.name).join '|'})\\b/gi"
      else
        onVacationUsers = []
        onVacationRegex = null
      callback? onVacationUsers

  userOnVacationMentioned = (message) ->
    return false if not onVacationRegex
    return false if not message.match?
    return false if not msg.message.user?.id
    return message.match onVacationRegex

  robot.listen userOnVacationMentioned, (msg) ->
    for username in msg.match
      username = username.toLowerCase()
      user = _(onVacationUsers).find (user) -> user.name is username
      date = nextWeekday user.event.end
      msg.send "<@#{msg.message.user.id}>: #{obfuscator.obfuscate user.name} is on vacation returning #{ date.fromNow() } on #{ date.format 'dddd MMMM Do' } :sunglasses:"

  robot.brain.once 'loaded', ->
    refreshVacationList (users) ->
      robot.logger.info "Users on vacation: #{users.map((u) -> "@#{u.name}").join ", "}"

    new cronJob( "0 0 * * * *", refreshVacationList, null, true)

  robot.respond /(who\s?is )?on vacation/, (msg) ->
    refreshVacationList (users) ->
      vacationers = users.map (user) -> obfuscator.obfuscate user.name
      if vacationers.length > 0
        msg.send "<@#{msg.message.user.id}>: #{ vacationers.join ' , ' } #{if vacationers.length > 1 then "are" else "is the only one"} on vacation :sunglasses:"
      else
        msg.send "<@#{msg.message.user.id}>: No one is on vacation :sadpanda:"

