# Description:
#  A bot that helps you schedule meetings
#
# Dependencies:
#   - moment
#
# Configuration:
#   HUBOT_AGORA_URL - eg. "http://localhost:5555"
#   HUBOT_MEETING_VERIFICATION_TOKEN - A token required to be passed as an Authorization Basic
#
# Commands:
#   list rooms - show all the meeting rooms
#   book a room - quickly book a meeting room for use right now
#
# Author:
#   ndaversa

_ = require "underscore"
moment = require "moment"

Bot = require "../bot"
SlackButtons = require "../bot/slackbuttons"
Server = require "../bot/server"
Config = require "../config"
Utils = require "../utils"

class MeetingBot extends Bot
  @include Server
  @include SlackButtons

  constructor: (@robot) ->
    return new MeetingBot @robot unless @ instanceof MeetingBot
    @commands = [
      regex: /(room(s)? list|list rooms)/i
      name: "listRoomsCommand"
    ,
      regex: /book(?: me)? a room/i
      name: "instantBookCommand"
    ]

    @endpoints = [
      path: "/hubot/meeting/checkin"
      type: "post"
      func: @postMeetingCheckin
    ]

    @requests = {}
    @checkins = {}

    @imHereButton =
      name: "status"
      value: "confirm"
      text: "I'm here"
      type: "button"
      style: "primary"
      func: @onStatusButton

    @runningLateButton =
      name: "status"
      value: "late"
      text: "I'm running late"
      type: "button"
      func: @onStatusButton

    @cantMakeItButton =
      name: "status"
      value: "deny"
      text: "Can't make it"
      type: "button"
      style: "danger"
      func: @onStatusButton

    @fifteenMinsButton =
      name: "duration"
      value: 15
      text: "15 minutes"
      type: "button"
      style: "primary"
      func: @onDurationButton

    @thirtyMinsButton =
      name: "duration"
      value: 30
      text: "30 minutes"
      type: "button"
      func: @onDurationButton

    @oneHourButton =
      name: "duration"
      value: 60
      text: "1 hour"
      type: "button"
      func: @onDurationButton

    @slackButtons = [ @fifteenMinsButton, @thirtyMinsButton, @oneHourButton, @imHereButton, @runningLateButton, @cantMakeItButton ]
    super

  queueCheckin: (meeting, user) ->
    id = "#{Date.now()}_#{user.name}"
    @checkins[id] =
      meeting: meeting
      user: user
    id

  queueRequest: (context) ->
    id = Date.now()
    @requests[id] = context
    id

  onDurationButton: (payload, action) ->
    context = @requests[payload.callback_id]
    @bookRoom
      context: context
      duration: parseInt action.value, 10
    payload.original_message.attachments = [
      text: "Attempting to book a #{action.value} minute meeting..."
    ]

  onStatusButton: (payload, action) ->
    checkin = @checkins[payload.callback_id]
    attendees = _(checkin.meeting.attendees).without(checkin.user.email_address).map (attendee) ->
      Utils.lookupChatUserByEmail attendee
    attachments = payload.original_message.attachments
    attachments.shift() # Remove the buttons

    switch action.value
      when "confirm"
        @checkinRoom(checkin)
        .then (json) =>
          attachments.unshift text: "I have checked you in. Thank you"
        .catch (error) =>
          attachments.unshift text: "Sorry, I was unable to check you in :sadpanda:"
      when "late"
        if attendees.length > 0
          @dm attendees, "<@#{checkin.user.id}> is running late to `#{checkin.meeting.description}`"
          attachments.unshift text: "I will let #{attendees.map((a) -> "<@#{a.id}>").join ", "} know you are running late"
        else
          @cancelMeeting(checkin.meeting.id)
          .then (json) =>
            attachments.unshift text: "Okay I have cancelled this meeting since you are the only attendee"
          .catch (error) =>
            attachments.unshift text: "Sorry, I was unable to cancel this meeting :sadpanda:"
      when "deny"
        if attendees.length > 0
          @dm attendees, "<@#{checkin.user.id}> will not be able to attend `#{checkin.meeting.description}`"
          attachments.unshift text: "I will let #{attendees.map((a) -> "<@#{a.id}>").join ", "} know you will not be attending"
        else
          @cancelMeeting(checkin.meeting.id)
          .then (json) =>
            attachments.unshift text: "Okay I have cancelled this meeting since you are the only attendee"
          .catch (error) =>
            attachments.unshift text: "Sorry, I was unable to cancel this meeting :sadpanda:"

  roomAttachment: (room) ->
    fallback: room.name
    thumb_url: room.cover
    fields: [
      title: "Room"
      value: room.name
      short: yes
    ,
      title: "Capacity"
      value: room.capacity
      short: yes
    ,
      title: "Location"
      value: room.location
      short: no
    ]

  checkinRoom: (details) ->
    @fetch "#{Config.meeting.server.url}/enter",
      method: "POST"
      body: JSON.stringify
        beacon: details.meeting.room.beacon
        attendee: details.user.email_address

  cancelMeeting: (id) ->
    @fetch "#{Config.meeting.server.url}/meeting",
      method: "DELETE"
      body: JSON.stringify
        id: checkin.meeting.id

  bookRoom: (details) ->
    @fetch "#{Config.meeting.server.url}/instant",
      method: "POST"
      body: JSON.stringify
        owner: details.context.message.user.profile.email
        duration: details.duration
    .then (json) =>
      start = moment json.startTime
      end = moment json.endTime
      @send details.context,
        text: "Okay I have booked you *#{json.room.name}* from #{start.format("LT")} to #{end.format("LT")} (#{start.to end, yes})"
        attachments: [ @roomAttachment json.room ]
    .catch (error) =>
      @send details.context, "I was unable to book you a room :sadpanda:"

  listRoomsCommand: (context) ->
    @fetch("#{Config.meeting.server.url}/rooms")
    .then (json) =>
      attachments = []
      attachments.push @roomAttachment room for room in json
      @send context,
        text: ":house:"
        attachments: attachments

  instantBookCommand: (context) ->
    id = @queueRequest context
    @send context,
      text: "<@#{context.message.user.id}> I will try to find a room for you, how much time do you need?"
      attachments: [ @buttonsAttachment id, name: "duration" ]

  isAuthorized: (req, res) ->
    unless authorized = req.headers.authorization is "Basic #{Config.meeting.verification.token}"
      @robot.logger.debug "MeetingBot: invalid token provided" unless authorized
      res.status(403).send "Not authorized"
    return authorized

  confirmCheckin: (json) ->
    success = yes
    users = json.attendees.map (attendee) ->
      unless user = Utils.lookupChatUserByEmail attendee
        success = no
      return user

    start = moment json.startTime
    end = moment json.endTime

    for user in users when user
      buttons = @buttonsAttachment @queueCheckin(json, user), name: "status"
      buttons.text = "Please confirm your attendance..."

      @dm user,
        text: """
          You have `#{json.description}` #{start.fromNow()}
          starting at #{start.format("LT")} to #{end.format("LT")} for #{start.to end, yes}
        """
        attachments: [
          buttons
          @roomAttachment json.room
        ]
    return success

  postMeetingCheckin: (req, res) ->
    return res.status(400).send "Missing id" unless req.body.id?
    return res.status(400).send "Missing room" unless req.body.room?
    return res.status(400).send "Missing description" unless req.body.description?
    return res.status(400).send "Missing startTime" unless req.body.startTime?
    return res.status(400).send "Missing endTime" unless req.body.endTime?
    return res.status(400).send "Missing owner" unless req.body.owner?
    return res.status(400).send "Missing attendees" unless req.body.attendees? and req.body.attendees.length > 0
    if @confirmCheckin req.body
      res.send 'OK'
    else
      res.status(404).send "Unable to notify all attendees"

module.exports = MeetingBot
