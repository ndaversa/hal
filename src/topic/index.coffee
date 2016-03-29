# Description:
# Read an ical feed and prepend the current event to the channel topic
#
# Dependencies:
# - coffee-script
# - moment
# - cron
# - ical
# - underscore
#
# Configuration:
# HUBOT_ICAL_CHANNEL_MAP `\{\"ops\":\"HTTP_ICAL_LINK\",\"data\":\"HTTP_ICAL_LINK\"\}`
# HUBOT_ICAL_LABEL_CHANNEL_MAP `\{\"ops\":\"On\ duty\"\,\"engineering\":\"Oncall\"\}`
# HUBOT_ICAL_DUPLICATE_RESOLVER - When finding multiple events for `now` use the presence of this string to help choose winner
#    Note: Default value is `OVERRIDE: ` to handle calendars like VictorOps
# HUBOT_ICAL_CRON_JOB - How often to check for updates in cron time, default `0 */15 * * * *` which is every 15 mins everyday
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require 'underscore'
cronJob = require("cron").CronJob
ical = require 'ical'
moment = require 'moment'

Bot = require "../bot"
Config = require "../config"
Utils = require "../utils"

class TopicBot extends Bot

  constructor: (@robot) ->
    @commands = [
      regex: /topic refresh/
      name: "topicRefreshCommand"
    ,
      regex: /topic (.*)/
      name: "topicChangeCommand"
    ]
    super

    @robot.brain.once 'loaded', =>
      new cronJob(Config.topic.cronTime, @updateTopics.bind(this), null, true)
      @updateTopics()

  currentEvent: (room, cb) ->
    now = moment()
    calendar = Config.topic.calendars[room]
    ical.fromURL calendar, {}, (err, data) ->
      events = _(data).keys().map (id) ->
        event = data[id]
        start: moment event.start
        end: moment event.end
        summary: event.summary
        id: id
      .filter (event) -> now.isBetween event.start, event.end

      if events.length is 1
        event = events[0]
      else
        events = events.filter (event) -> event.summary.indexOf(Config.topic.duplicateResolution) > -1
        if events.length is 1
          event = events[0]

      event.summary = event.summary.replace Config.topic.duplicateResolution, '' if event?
      cb event

  updateTopicForRoom: (room) ->
    label = Config.topic.labels[room]
    channel = Utils.getRoom room
    Utils.getRoomTopic(channel.id, channel.getType())
    .then (room) =>
      currentTopic = room.topic
      @currentEvent room.name, (event) ->
        format = "__LABEL__: __EVENT__ | __LEFTOVER__"
        regex = new RegExp Config.topic.regex.replace("__LABEL__", label), "i"
        [ __, ___, leftover ] = currentTopic.match regex

        if event
          user = Utils.fuzzyFindChatUser(event.summary) if event.summary?.length > 0
          summary = "@#{user.name}" if user?
          summary ?= event.summary
        else
          format = "__LEFTOVER__"

        topic =
          format
          .replace("__LABEL__", label)
          .replace("__EVENT__", summary)
          .replace("__LEFTOVER__", leftover)

        if topic isnt currentTopic
          Utils.setTopic channel.id, topic

  updateTopics: ->
    for room of Config.topic.calendars
      @updateTopicForRoom room

  topicRefreshCommand: (context) ->
    context.finish()
    room = Utils.getRoom context.message.room
    @send context, "Refreshing topics"
    @updateTopics()

  topicChangeCommand: (context) ->
    [ __, topic ] = context.match
    room = Utils.getRoom context.message.room
    @send context, "Setting topic for <##{room.id}|#{room.name}> to `#{topic}`"
    Utils.setTopic room.id, topic

module.exports = TopicBot
