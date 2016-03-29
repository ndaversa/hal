# Description:
#  Reads a birthday calendar and matches with Slack users
#  In turn, providing notifications on their birthdays
#
# Dependencies:
#   - underscore
#   - ical
#   - moment
#   - fuse.js
#   - cron
#
# Configuration:
#   HUBOT_BIRTHDAY_ICAL
#
# Commands:
#   hubot birthdays - Find out who has a birthday coming up
#
# Author:
#   ndaversa

_ = require 'underscore'
moment = require 'moment'
ical = require 'ical'
cronJob = require("cron").CronJob

Bot = require "../bot"
Config = require "../config"
Utils = require "../utils"

class BirthdayBot extends Bot

  constructor: (@robot) ->
    @commands = [
      regex: /birthdays/
      name: "upcomingBirthdaysCommand"
    ]
    @robot.brain.once 'loaded', =>
      new cronJob( "00 00 10 * * *", @sendHappyBirthdayMessages, null, true)
    super

  upcomingBirthdays:  []

  lookupUser: (event) ->
    user = Utils.fuzzyFindChatUser event.name
    user.event = event
    user

  sendHappyBirthdayMessages: =>
    @refreshBirthdayList (users) =>
      today = moment().startOf 'day'
      birthdays = users.map (user) =>
        if user.event.start.isSame today, 'day'
          @send user.id, "Happy birthday :balloon: :tada:"

  fetchUpcomingBirthdays: (callback) ->
    ical.fromURL Config.birthday.calendar.url, {}, (err, data) =>
      start = moment().startOf 'day'
      end = moment().startOf('day').add(7, 'days').endOf('day')

      birthdays = _(data).keys().map (id) ->
        event = data[id]
        start: moment event.start
        end: moment event.end
        summary: event.summary
        id: id
      .filter (event) ->
        event.start.isBetween(start, end, null, '[]')
      .map (event) ->
        event.name = event.summary.split('- Birthday')[0].trim()
        event
      .map @lookupUser
      callback _(birthdays).compact()

  refreshBirthdayList: (callback) =>
    @robot.logger.debug 'Refreshing birthday list'
    @fetchUpcomingBirthdays (users) =>
      @upcomingBirthdays = users or []
      callback? @upcomingBirthdays

  upcomingBirthdaysCommand: (context) ->
    @refreshBirthdayList (users) =>
      today = moment().startOf 'day'
      birthdays = users.map (user) =>
        if user.event.start.isSame today, 'day'
          "<@#{user.id}>'s birthday is today :birthday:. Join me in wishing them a happy birthday!:balloon: :tada:"
        else
          "<@#{user.id}>'s birthday is #{today.to user.event.start} on #{user.event.start.format "dddd MMMM Do"}"
      if birthdays.length > 0
        @send context, """
          #{birthdays.join "\n"}
        """
      else
        @send context, "There are no birthdays in the next 7 days :sadpanda:"

module.exports = BirthdayBot
