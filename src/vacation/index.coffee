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
#   hubot on vacation - Find out who's on vacation right now
#
# Author:
#   ndaversa

_ = require 'underscore'
moment = require 'moment'
ical = require 'ical'
cronJob = require("cron").CronJob
Obfuscator = require '../utils/obfuscator'
obfuscator = new Obfuscator Obfuscator.PerfectObfuscator

Bot = require "../bot"
Config = require "../config"
Utils = require "../utils"

class VacationBot extends Bot

  constructor: (@robot) ->
    @commands = [
      regex: new RegExp "^(?:Reminder:(?: #{@robot.name})?|#{@robot.name}) (who\\s?is )?on vacation\\.?$"
      hear: yes
      name: "whoisOnVacationCommand"
    ,
      listen: @wasUserOnVacationMentioned
      func:  @userOnVacationMentioned
    ]
    @robot.brain.once 'loaded', =>
      new cronJob( "0 0 * * * *", @refreshVacationList, null, true)
      @refreshVacationList (users) ->
        @robot.logger.info "Users on vacation: #{users.map((u) -> "@#{u.name}").join ", "}"
    super

  onVacationUsers:  []
  onVacationRegex: null

  lookupUser: (event) ->
    user = Utils.fuzzyFindChatUser event.name
    if user?
      user.event = event
    else
      @robot.logger.error "VacationBot: Cannot find #{event.name}"
    user

  shouldNotifyOfVacation: (context, user) ->
    room = context.message.room
    key = "#{room}:#{user.id}"

    if Utils.cache.get key
      @robot.logger.info "Supressing vacation mention for #{user.name} in #{room}"
      return no
    else
      Utils.cache.put key, true
      return yes

  nextWeekday: (date) ->
    switch date.weekday()
      when 0 then return date.weekday 1 # sunday > monday
      when 6 then return date.weekday 8 # saturday > monday
      else return date

  determineWhosOnVacation: (callback) ->
    now = moment()
    ical.fromURL Config.vacation.calendar.url, {}, (err, data) =>
      onVacation = _(data).keys().map (id) ->
        event = data[id]
        start: moment event.start
        end: moment event.end
        summary: event.summary
        id: id
      .filter (event) ->
        now.isBetween event.start, event.end
      .map (event) ->
        event.name = event.summary.split(/\(.*\)/)[0].trim()
        event
      .map @lookupUser
      callback _(onVacation).compact()

  refreshVacationList: (callback) =>
    @robot.logger.debug 'Refreshing vacation list'
    @determineWhosOnVacation (users) =>
      if users and users.length > 0
        @onVacationUsers = users
        @onVacationRegex = new RegExp "\\b(#{(users.map (user) -> user.name).join '|'})\\b", "gi"
      else
        @onVacationUsers = []
        @onVacationRegex = null
      callback? @onVacationUsers

  wasUserOnVacationMentioned: (context) ->
    return false if not @onVacationRegex
    return false if not context.match?
    return false if not context.user.id
    return context.match @onVacationRegex

  userOnVacationMentioned: (context) ->
    for username in context.match
      username = username.toLowerCase()
      user = _(@onVacationUsers).find (user) -> user.name is username
      date = @nextWeekday user.event.end
      if @shouldNotifyOfVacation context, user
        @send context, "
          <@#{context.message.user.id}>:
           #{obfuscator.obfuscate user.name} is on vacation 
           returning #{ date.fromNow() }
           on #{ date.format 'dddd MMMM Do' } :sunglasses:
        "

  whoisOnVacationCommand: (context) ->
    @refreshVacationList (users) =>
      vacationers = users.map (user) =>
        date = @nextWeekday user.event.end
        "`#{obfuscator.obfuscate user.name}` is on vacation returning *#{ date.fromNow() }* on _#{ date.format 'dddd MMMM Do' }_"
      if vacationers.length > 0
        @send context, """
          :beach_with_umbrella: :sunglasses:

          #{vacationers.join "\n"}
        """
      else
        @send context, "No one is on vacation :sadpanda:"

module.exports = VacationBot
