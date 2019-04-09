# Description:
#  A bot that exposes an API to register and track test devices
#
# Dependencies:
#   - underscore
#   - node-fetch
#
# Configuration:
#   HUBOT_TRACKER_VERIFICATION_TOKEN
#
# Commands:
#   None
#
# Author:
#   ndaversa

_ = require "underscore"
s = require "underscore.string"
moment = require "moment"

Bot = require "../bot"
SlackButtons = require "../bot/slackbuttons"
Server = require "../bot/server"
Config = require "../config"
Utils = require "../utils"
Devices = require "../tracker/devices"
Sessions = require "../tracker/sessions"
crypto = require "crypto"

class TrackerBot extends Bot
  @include Server
  @include SlackButtons

  constructor: (@robot) ->
    return new TrackerBot @robot unless @ instanceof TrackerBot

    @endpoints = [
      path: "/hubot/tracker/device/register"
      type: "post"
      func: @postDeviceRegister
    ,
      path: "/hubot/tracker/device/pushtoken"
      type: "post"
      func: @postDevicePushToken
    ,
      path: "/hubot/tracker/device/session/start"
      type: "post"
      func: @postDeviceSessionStart
    ,
      path: "/hubot/tracker/device/session/end"
      type: "post"
      func: @postDeviceSessionEnd
    ]

    @commands = [
      regex: /device list/i
      name: "deviceListCommand"
    ,
      regex: /device sessions/i
      name: "deviceSessionsCommand"
    ]

    @pingButton = 
      name: "ping"
      text: "Ping"
      type: "button"
      style: "primary"
      func: @onPingButtonAction

    @deleteButton = 
      name: "delete"
      text: "Delete"
      type: "button"
      style: "danger"
      func: @onDeleteButtonAction

    @slackButtons = [ @pingButton, @deleteButton ]
    @devices = new Devices @robot
    @sessions = new Sessions @robot
    super

  isValid: (payload) ->
    try
      if device = @devices.get payload.callback_id
        return yes
      else
        return no
    catch
      return no

  isAuthorized: (req, res) ->
    unless authorized = req.headers.authorization is "Basic #{Config.tracker.verification.token}"
      @robot.logger.debug "Device Tracker: invalid token provided" unless authorized
      res.status(403).send "Not authorized"
    return authorized

  postDeviceRegister: (req, res) ->
    response = @register req.body
    res.json response

  postDevicePushToken: (req, res) ->
    res.send 'OK'

  postDeviceSessionStart: (req, res) ->
    return res.status(400).send "Missing id" unless req.body.id?
    return res.status(400).send "Missing name" unless req.body.name?
    return res.status(400).send "Missing email" unless req.body.email?
    response = @createSession req.body
    res.json response

  postDeviceSessionEnd: (req, res) ->
    return res.status(400).send "Missing id" unless req.body.id?
    return res.status(400).send "Missing name" unless req.body.name?
    return res.status(400).send "Missing email" unless req.body.email?
    @endSession req.body
    res.send 'OK'

  onPingButtonAction: (payload, action) ->
    user = payload.user
    msg = payload.original_message
    device = @devices.get payload.callback_id
    session = @sessions.get payload.callback_id
    holder = Utils.lookupChatUserByEmail session.email

    msg.attachments.push
      text: "<@#{user.id}> pinged <@#{holder.id}> about this device"
    @send message: room: holder.id,
      text: "<@#{user.id}> is looking for a device you last had"
      attachments: [ @deviceAttachment device ]

  onDeleteButtonAction: (payload, action) ->
    msg = payload.original_message
    device = @devices.get payload.callback_id
    session = @sessions.get payload.callback_id

    if actionAttachment = _(msg.attachments).find(callback_id: device.id)
      @devices.remove device
      @sessions.end session
      index = _(msg.attachments).indexOf(actionAttachment) - 1
      deviceAttachment = msg.attachments[index]
      msg.attachments = _(msg.attachments).without actionAttachment, deviceAttachment
    else
      msg.attachments.push
        text: "Cannot delete device #{device.id}"

  register: (device) ->
    id = crypto.createHash("md5").update("#{device.physical_id}").digest("hex").substr 0, 7
    device.id = id
    @devices.add device
    return device

  createSession: (user) ->
    session = @sessions.create user

  endSession: (user) ->
    @sessions.end user

  sessionAttachment: (user, device, session) ->
    _(@deviceAttachment device).extend
      author_name: user.real_name
      author_icon: user.slack.profile.image_512
      fields: [
        title: "Checked out"
        value: moment(session.time).fromNow()
        short: yes
      ]

  deviceAttachment: (device) ->
    color: "#A4C639"
    title: ":iphone: #{s.capitalize(device.manufacturer)} [#{device.model}] - #{device.os} [SDK #{device.sdk}] - #{device.id}"

  deviceSessionsCommand: (context) ->
    attachments = []

    for id, session of @sessions.all()
      device = @devices.get id
      user = Utils.lookupChatUserByEmail(session.email) or
        real_name: session.name
        slack: profile: image_512: ""

      attachments.push @sessionAttachment user, device, session
      attachments.push @buttonsAttachment device.id, [ _(@pingButton).extend value: user.id ]

    if attachments.length is 0
      @send context, "No active sessions"
    else
      @send context, attachments: attachments

  deviceListCommand: (context) ->
    try
      attachments = []

      for id, device of @devices.all()
        attachments.push @deviceAttachment device
        attachments.push @buttonsAttachment device.id, [ _(@deleteButton).extend value: device.id ]

      if attachments.length is 0
        @send context, "No Devices :sadpanda:"
      else
        console.log attachments
        @send context,
          text: ":android: :iphone:"
          attachments: attachments
    catch e
      console.log e

module.exports = TrackerBot
