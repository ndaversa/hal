_ = require "underscore"
cache = require "memory-cache"
fetch = require "node-fetch"
icalendar = require "icalendar"
Fuse = require 'fuse.js'
Config = require "../config"
StatsD = require('node-dogstatsd').StatsD

if Config.stats.host and Config.stats.port
  c = new StatsD Config.stats.host, Config.stats.port

class Utils

  @robot: null

  @fetch: (url, opts) ->
    options =
      headers:
        "Content-Type": "application/json"
    options = _(options).extend opts

    Utils.robot.logger.debug "Fetching: #{url}"
    fetch(url,options).then (response) ->
      if response.status >= 200 and response.status < 300
        return response
      else
        error = new Error "#{response.statusText}: #{response.url.split("?")[0]}"
        error.response = response
        throw error
    .then (response) ->
      length = response.headers.get 'content-length'
      response.json() unless length is "0" or length is 0 or response.status is 204
    .catch (error) ->
      Utils.robot.logger.error error
      Utils.robot.logger.error error.stack
      try
        error.response.json().then (json) ->
          Utils.robot.logger.error JSON.stringify json
          message = "\n`#{error}`"
          message += "\n`#{v}`" for k,v of json.errors
          throw message
      catch e
        throw error

  @normalizeContext: (context) ->
    if _(context).isString()
      normalized = message: room: context
    else if context?.room
      normalized = message: context
    else if context?.message?.room
      normalized = context
    normalized

  @getRoom: (context) ->
    context = @normalizeContext context
    room = @robot.adapter.client.rtm.dataStore.getChannelOrGroupByName context.message.room
    room = @robot.adapter.client.rtm.dataStore.getChannelGroupOrDMById context.message.room unless room
    room = @robot.adapter.client.rtm.dataStore.getDMByUserId context.message.room unless room
    room = @robot.adapter.client.rtm.dataStore.getDMByName context.message.room unless room
    room

  @getRoomName: (context) ->
    room = @getRoom context
    room.name

  @getUsers: ->
    @robot.adapter.client.rtm.dataStore.users

  @lookupChatUser: (username) ->
    users = Utils.getUsers()
    result = (users[user] for user of users when users[user].name is username)
    if result?.length is 1
      return result[0]
    return null

  @lookupChatUserByEmail: (email) ->
    users = Utils.getUsers()
    result = (users[user] for user of users when users[user].email_address is email)
    if result?.length is 1
      return result[0]
    return null

  @authorizeUser = (msg, usergroup) ->
    Utils.fetch("https://slack.com/api/usergroups.users.list?token=#{Config.slack.token}&usergroup=#{usergroup}")
    .then (json) ->
      if not _(json.users).contains msg.message.user.id
        throw "You are not authorized to use this feature, you must be part of the <!subteam^#{usergroup}> group. Please visit <#C06RDDDC4> to make your case for permission"
    .catch (error) ->
      msg.send "<@#{msg.message.user.id}> #{error}"
      Promise.reject error

  @getUsersInGroup = (usergroup) ->
    if users = Utils.cache.get "Utils:getUsersInGroup:#{usergroup}"
      Promise.resolve users
    else
      Utils.fetch("https://slack.com/api/usergroups.users.list?token=#{Config.slack.token}&usergroup=#{usergroup}")
      .then (json) =>
        users = json.users.map (user) =>
          Utils.getUsers()[user]
        Utils.cache.put "Utils:getUsersInGroup:#{usergroup}", users, Config.cache.usergroups.users.expiry
        users

  @getGroupInfo = (usergroup) ->
    if json = Utils.cache.get "Utils:getGroupInfo"
      groupList =  Promise.resolve json
    else
      groupList = 
        Utils.fetch("https://slack.com/api/usergroups.list?token=#{Config.slack.token}")
        .then (json) ->
          Utils.cache.put "Utils:getGroupInfo", json, Config.cache.usergroups.list.expiry
          json

    groupList.then (json) ->
      group = _(json.usergroups).findWhere id: usergroup
      group = _(json.usergroups).findWhere handle: usergroup unless group
      group

  @getCalendarFromURL = (url) ->
    if body = Utils.cache.get "Utils:getCalendarFromURL:#{url}"
      Promise.resolve icalendar.parse_calendar body
    else
      fetch(url)
      .then (res) =>
        res.text()
      .then (body) =>
        Utils.cache.put "Utils:getCalendarFromURL:#{url}", body, Config.cache.calendar.expiry
        icalendar.parse_calendar body

  @getCalendarsFromURLs = (urls) ->
    Promise.all(
      urls.map (url) -> Utils.getCalendarFromURL url
    )

  @fuzzyFindChatUser: (name, users=Utils.getUsers()) ->
    users = _(users).keys().map (id) ->
      u = users[id]
      if not u.deleted and not u.is_bot and u.profile.email?.includes '@ecobee'
        id: u.id
        name: u.profile.display_name.toLowerCase() or u.profile.real_name.toLowerCase()
        real_name: u.real_name.toLowerCase()
        email: u.profile.email?.split('@')[0].toLowerCase() or ''
      else
        null
    users = _(users).compact()

    f = new Fuse users,
      keys: [
        name: "name"
        weight: 0.2
      ,
        name: "real_name"
        weight: 0.8
      ]
      shouldSort: yes
      verbose: no
    results = f.search name.replace(/\W+/g, " ") if name
    result = if results? and results.length >=1 then results[0] else null
    Utils.robot.logger.debug "Matching `#{name}` with @#{result?.name}"
    return result

  @getRoomTopic: (id, type) ->
    @robot.adapter.client.web["#{type}s"].info(id)
    .then (details) ->
      topic: details[type].topic.value
      name: details[type].name
      id: details[type].id

  @setTopic: (id, topic) ->
    topic = _(topic).unescape()
    opts = 
      channel: id
      topic: encodeURIComponent topic
      token: Config.slack.token

    switch id[0]
      when "G"
        endpoint = "groups"
      when "C"
        endpoint = "channels"
      else
        return Promise.reject()

    qs = ("#{key}=#{value}" for key, value of opts).join "&"
    Utils.fetch("https://slack.com/api/#{endpoint}.setTopic?#{qs}")
    .catch (error) =>
      Utils.robot.logger.error "An error occured trying to update the Jedi channel topic #{error}"

  @cache:
    put: (key, value, time=Config.cache.expiry) -> cache.put key, value, time
    get: cache.get
    del: cache.del

  @Stats:
    increment: (label, tags) ->
      try
        label = label
          .replace( /[\/\(\)-]/g, '.' ) #Convert slashes, brackets and dashes to dots
          .replace( /[:\?]/g, '' ) #Remove any colon or question mark
          .replace( /\.+/g, '.' ) #Compress multiple periods into one
          .replace( /\.$/, '' ) #Remove any trailing period

        console.log "#{Config.stats.prefix}.#{label}", tags if Config.debug
        c.increment "#{Config.stats.prefix}.#{label}", tags if c
      catch e
        console.error e

Utils.Stats.increment "boot"
module.exports = Utils
