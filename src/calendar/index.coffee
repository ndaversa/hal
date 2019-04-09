# Description:
#  A bot that ...
#
# Dependencies:
#   - moment
#   - icalendar
#   - underscore
#
# Configuration:
#   EXPRESS_URL
#   HUBOT_CALENDAR_VERIFICATION_TOKEN
#   HUBOT_CALENDAR_MAP
#       "vacation": [
#         {
#           "chapter": {
#             "id:": "C024GR3KC",
#             "name": "Everyone"
#           },
#           "url": "vacationcalendarurl"
#         }
#       ]
#     }
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
s = require "underscore.string"
moment = require "moment"
icalendar = require 'icalendar'

Bot = require "../bot"
SlackButtons = require "../bot/slackbuttons"
Server = require "../bot/server"
Config = require "../config"
Utils = require "../utils"

class CalendarBot extends Bot
  @include SlackButtons
  @include Server

  constructor: (@robot) ->
    return new CalendarBot @robot unless @ instanceof CalendarBot
    @requests = {}

    @commands = [
      regex: /calendar link for <?@([\w._-]*)>?/i
      name: "requestCalendarLinkForGroup"
    ]

    @endpoints = [
      path: "/hubot/calendar/:token/:usergroup/:type"
      type: "get"
      func: @getCalendarForGroupType
    ]

    @slackButtons = [
      name: "type"
      value: "vacation"
      text: "Vacation"
      type: "button"
      style: "primary"
      func: @onTypeButton
    ]
    super

  isAuthorized: -> yes #Doing auth via token in URL

  credentials: 
    token: Config.slack.token

  queueRequest: (context) ->
    id = Date.now()
    @requests[id] = context
    id

  dequeueRequest: (id) ->
    rc = @requests[id]
    delete @requests[id]
    rc

  onTypeButton: (payload, action) ->
    attachments = payload.original_message.attachments
    attachments.shift() # Remove the buttons

    details = @dequeueRequest payload.callback_id
    unless details
      return attachments.unshift text: "Sorry I was unable to process your request :sadpanda:"

    link = @generateCalendarLinkForGroup details.usergroup, action.value
    switch action.value
      when "vacation"
        attachments.unshift text: "Here is a calendar URL that includes
         the #{s.capitalize action.value} schedule for everyone in
         <!subteam^#{details.usergroup.id}|#{details.usergroup.handle}>:\n\n
         #{link}\n\n
         Copy this URL and import it into your calendar solution of choice :smile:
        "

  generateCalendarLinkForGroup: (usergroup, type) ->
    "#{Config.server.url}/hubot/calendar/#{Config.calendar.verification.token}/#{usergroup.id}/#{type}"

  requestCalendarLinkForGroup: (context) ->
    [ __, handle ] = context.match

    Utils.getGroupInfo(handle)
    .then (usergroup) =>
      id = @queueRequest
        context: context
        usergroup: usergroup

      @send context,
        text: "What kind of calendar link do you want?"
        attachments: [ @buttonsAttachment id, name: "type" ]
    .catch (error) =>
      @send context,
        text: "Sorry I was unable to find the @#{handle} usergroup"

  getCalendarForGroupType: (req, res) ->
    return res.status(404).send "Not a valid calendar" unless Config.calendar.verification.token is req.params.token
    return res.status(400).send "Invalid calendar type" unless Config.calendar.map[req.params.type]?

    calendar = new icalendar.iCalendar()
    calendar.setProperty "PRODID", "-//HAL//#{@robot.name}//EN"

    users = null
    Utils.getGroupInfo(req.params.usergroup)
    .then (usergroup) ->
      calendar.setProperty "X-WR-CALNAME", "#{s.capitalize(req.params.type)}: @#{usergroup.handle} (#{usergroup.name})"
      Utils.getUsersInGroup(req.params.usergroup)
    .then (_users) ->
      users = _users
      Utils.getCalendarsFromURLs Config.calendar.map[req.params.type].map (c) -> c.url
    .then (calendars) ->
      for c in calendars
        c.events().map (event) ->
          summary = event.getPropertyValue "SUMMARY"
          summary = summary.split(/\(.*\)/)[0].trim() if req.params.type is "vacation"
          user = Utils.fuzzyFindChatUser summary
          if user and _(users).findWhere(id: user.id)
            calendar.addComponent event
      res.header("Content-Type","text/calendar; charset=UTF-8")
      .send calendar.toString()
    .catch (error) =>
      @robot.logger.error error
      res.status(404).send "Invalid group specified"

module.exports = CalendarBot
